module PushyDaemon
  class ShouterResponseError       < StandardError; end
  class ShouterChannelClosed       < StandardError; end
  class ShouterPreconditionFailed  < StandardError; end
  class ShouterInterrupted         < StandardError; end
  class EndpointTopicContext       < StandardError; end

  class Shouter < BmcDaemonLib::MqEndpoint
    include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
    include BmcDaemonLib::LoggerHelper

    # Class options
    attr_accessor :table
    attr_accessor :logger

    def initialize(conn, config_shout)
      # Init
      @shouter_keys = []
      @channel = nil
      @exchange = nil

      # Prepare logger
      @logger = BmcDaemonLib::LoggerPool.instance.get :shouter

      # Check config
      unless config_shout && config_shout.any? && config_shout.is_a?(Enumerable)
        log_error "prepare: empty [shout] section"
        return
      end

      # Extract information
      @shouter_keys = config_shout[:keys] if config_shout[:keys].is_a? Array
      @shouter_topic = config_shout[:topic]
      @shouter_period = config_shout[:period].to_i
      @shouter_period = 1 unless (@shouter_period > 0)

      fail PushyDaemon::EndpointTopicContext unless @shouter_topic

      # Create channel and exchange
      @channel = conn.create_channel
      @exchange = @channel.topic(@shouter_topic, durable: true, persistent: true)

      # Start working, now
      log_info "Shouter initialized, starting loop now", { topic: @shouter_topic, period: @shouter_period, keys: @shouter_keys }
    end

    def start_loop
      # Prepare exchange
      loop do
        # Generate payload
        payload = {time: Time.now.to_f, host: BmcDaemonLib::Conf.host}
        # payload = nil

        # Shout it !
        exchange_shout @exchange, payload
        sleep @shouter_period
      end
    rescue AMQ::Protocol::EmptyResponseError => e
      fail PushyDaemon::ShouterResponseError, "#{e.class} (#{e.inspect})"
    rescue Bunny::ChannelAlreadyClosed => e
      fail PushyDaemon::ShouterChannelClosed, "#{e.class} (#{e.inspect})"
    rescue Bunny::PreconditionFailed => e
      fail PushyDaemon::ShouterPreconditionFailed, "#{e.class} (#{e.inspect})"
    rescue Interrupt => e
      @channel.close
      fail PushyDaemon::ShouterInterrupted, e.class
    end

  protected

    def log_prefix
      [nil]
      # [self.class.name.split('::').last, :shouter]
    end

  private

    def exchange_shout exchange, body = {}
      # Prepare routing_key
      keys = []
      keys << @shouter_topic
      keys << SecureRandom.hex
      keys << @shouter_keys.sample if (@shouter_keys.is_a?(Array) && @shouter_keys.any?)
      routing_key = keys.join('.')

      # Announce shout
      log_message MSG_SEND, @shouter_topic, routing_key, body

      # Prepare headers
      app_id = "#{BmcDaemonLib::Conf.app_name}/#{BmcDaemonLib::Conf.app_ver}"
      headers = {
        sent_at: DateTime.now.iso8601(SHOUTER_SENTAT_DECIMALS),
        sent_by: app_id,
        }

      # Publish
      exchange.publish(body.to_json,
        routing_key: routing_key,
        headers: headers,
        app_id: app_id,
        content_type: "application/json",
        )
    end

    # NewRelic instrumentation
    #add_transaction_tracer :exchange_shout,  category: :task
    # add_transaction_tracer :shout,           category: :task

  end
end
