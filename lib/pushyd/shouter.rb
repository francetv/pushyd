module PushyDaemon
  class ShouterResponseError       < StandardError; end
  class ShouterChannelClosed       < StandardError; end
  class ShouterPreconditionFailed  < StandardError; end
  class ShouterInterrupted         < StandardError; end
  class EndpointTopicContext       < StandardError; end

  class Shouter < Endpoint

    attr_accessor :table

    def initialize
      # Init
      super
      @keys = []

      # Check config
      config_shout = Conf[:shout]
      unless config_shout && config_shout.any? && config_shout.is_a?(Enumerable)
        log_error "prepare: empty [shout] section"
        return
      end

      # Extract information
      @keys = config_shout[:keys] if config_shout[:keys].is_a? Array
      @topic = config_shout[:topic]
      @period = config_shout[:period] || 0

      # Start connexion to RabbitMQ and create channel
      @channel = connect_channel Conf.bus
      log_info "channel connected"

      # Create exchange
      fail PushyDaemon::EndpointTopicContext unless @topic
      @exchange = @channel.topic(@topic, durable: true, persistent: true)

      # Send shouter info to logs
      shouter_info = { topic: @topic, period: @period, keys: @keys }

    rescue Bunny::TCPConnectionFailedForAllHosts => e
      error "ERROR: cannot connect to RabbitMQ hosts (#{e.inspect})"
      log_info "shouter initialized", shouter_info
    end

    def shout
      return unless @exchange

      # Prepare exchange
      loop do
        random_string = SecureRandom.hex
        random_key = @keys.sample || "random"
        channel_shout [:ping, random_key, random_string], {dummy: true, time: Time.now.to_f, host: Conf.host}
        sleep @period
      end
    rescue AMQ::Protocol::EmptyResponseError => e
      fail PushyDaemon::ShouterResponseError, "#{e.class} (#{e.inspect})"
    rescue Bunny::ChannelAlreadyClosed => e
      fail PushyDaemon::ShouterChannelClosed, "#{e.class} (#{e.inspect})"
    rescue Bunny::PreconditionFailed => e
      fail PushyDaemon::ShouterPreconditionFailed, "#{e.class} (#{e.inspect})"
    rescue Interrupt => e
      @channel.close
      fail PushyDaemon::ShouterInterrupted, "#{e.class} (#{e.inspect})"
    end

  protected

  private

    def channel_shout keys, body = {}
      # Prepare headers
      headers = {
        sent_at: DateTime.now.iso8601,
        sent_by: Conf.app_name,
        }

      # Prepare exchange_name and routing_key
      exchange_name = @exchange.name
      routing_key = keys.unshift(exchange_name).join('.')

      # Announce shout
      log_message MSG_SEND, exchange_name, routing_key, body

      # Publish
      @exchange.publish(body.to_json,
        routing_key: routing_key,
        headers: headers,
        app_id: Conf.app_name,
        content_type: "application/json",
        )
    end

    # NewRelic instrumentation
    if Conf.newrelic_enabled?
      include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
      add_transaction_tracer :channel_shout,  category: :task
      add_transaction_tracer :shout,          category: :task
    end

  end
end
