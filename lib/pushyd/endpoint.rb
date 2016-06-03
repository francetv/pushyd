require 'bunny'
require 'securerandom'


# Constants
PROXY_MESSAGE_MAX   = 1
PROXY_USE_ACK       = false
PROXY_SCOPE         = "dev"

module PushyDaemon

  class EndpointConnexionContext    < StandardError; end
  class EndpointConnectionError     < StandardError; end
  class EndpointSubscribeContext    < StandardError; end
  class EndpointSubscribeError      < StandardError; end

  class Endpoint

    def initialize(logger)
      @logger = logger
    end

  protected

    def abort message
      @logger.error "ABORT #{self.class}: #{message}"
      raise "ABORT #{self.class}: #{message}"
    end

    def info message
      @logger.info "#{self.class}: #{message}"
    end

    def message params = {}
      # Indenting
      indent = " " * (params[:way].length)

      # Header
      @logger.info sprintf(
        "%3s %-15s %s",
        params[:way],
        params[:exchange],
        params[:key]
        )

      # Attributes
      if (params[:attrs].is_a? Hash)
        params[:attrs].each do |name, value|
          @logger.info sprintf("%s %-15s %s", indent, name, value)
        end
      end

      # Body (split in lines to log them separately)
      unless (params[:body].nil? || params[:body].empty?)
        JSON.pretty_generate(params[:body]).each_line do |line|
          @logger.info sprintf("%s %s", indent, line.rstrip)
        end
      end
    end

    # Start connexion to RabbitMQ
    def connect busconf
      raise PushyDaemon::EndpointConnexionContext, "invalid bus host/port" unless (busconf.is_a? Hash) &&
        busconf[:host] && busconf[:port]

      puts "connecting to #{busconf[:host]} port #{busconf[:port]}"
      conn = Bunny.new host: (busconf[:host].to_s || "localhost").to_s,
        port: busconf[:port].to_i,
        user: busconf[:user].to_s,
        pass: busconf[:pass].to_s,
        heartbeat: :server
      conn.start
    rescue Bunny::TCPConnectionFailedForAllHosts, Bunny::AuthenticationFailureError, AMQ::Protocol::EmptyResponseError  => e
      raise PushyDaemon::EndpointConnectionError, "error connecting (#{e.class})"
    rescue Exception => e
      raise PushyDaemon::EndpointConnectionError, "unknow (#{e.inspect})"
    else
      return conn
    end

    # Declare or return the exchange for this topic
    def channel_exchange topic
      @exchanges ||= {}
      @exchanges[topic] ||= @channel.topic(topic, durable: true, persistent: true)
    end

    # Subscribe to interesting topic/routes and bind a listenner
    def channel_subscribe rule
      # Check information
      rule_name = rule[:name].to_s
      rule_topic = rule[:topic].to_s
      rule_routes = rule[:routes].to_s.split(' ')
      rule_queue = "#{Config.name}-#{PROXY_SCOPE}-#{rule[:name]}"
      raise PushyDaemon::EndpointSubscribeContext, "rule [#{rule_name}] lacking topic" unless rule_topic
      raise PushyDaemon::EndpointSubscribeContext, "rule [#{rule_name}] lacking routes" if rule_routes.empty?

      # Create queue for this rule (remove it beforehand)
      #conn.create_channel.queue_delete(rule_queue_name)
      queue = @channel.queue(rule_queue, auto_delete: false, durable: true)

      # Bind each route from this topic-exchange
      topic_exchange = channel_exchange(rule_topic)
      rule_routes.each do |route|
        # Bind exchange to queue
        queue.bind topic_exchange, routing_key: route
        info "subscribe: bind [#{rule_topic}/#{route}] \t> #{rule_queue}"

        # Add row to config table
        @table.add_row [rule_name, rule_topic, route, rule[:relay].to_s, rule[:title].to_s ]
      end

      # Subscribe to our new queue
      queue.subscribe(block: false, manual_ack: PROXY_USE_ACK, message_max: PROXY_MESSAGE_MAX) do |delivery_info, metadata, payload|

        # Handle the message
        handle_message rule, delivery_info, metadata, payload

      end

    rescue Bunny::PreconditionFailed => e
      raise PushyDaemon::EndpointSubscribeError, "PreconditionFailed: [#{rule_topic}] code(#{e.channel_close.reply_code}) message(#{e.channel_close.reply_text})"

    rescue Exception => e
      raise PushyDaemon::EndpointSubscribeError, "unhandled (#{e.inspect})"

    end

    def handle_message rule, delivery_info, metadata, payload
    end

  end
end


# def prepare_shout


# # Prepare shout config
# shout_config = config[:shout]
# shout_exchange = nil
# shout_keys = []

# if shout_config.is_a? Hash
#   shout_exchange = topic(channel, shout_config[:topic])
#   shout_keys = shout_config[:keys] if shout_config[:keys].is_a? Array
# end

# end

# def endlessly
#   # Endless loop with shout config
#   begin
#     loop do
#       if shout_exchange
#         random_string = SecureRandom.hex
#         random_key = shout_keys.sample || "random"
#         shout shout_exchange, [:ping, random_key, random_string], {}
#       end
#       sleep 1
#     end
#   rescue AMQ::Protocol::EmptyResponseError => e
#     abort "ERROR: AMQ::Protocol::EmptyResponseError (#{e.inspect})"
#   rescue Bunny::TCPConnectionFailedForAllHosts => e
#     abort "ERROR: cannot connect to RabbitMQ hosts (#{e.inspect})"
#   rescue Bunny::ChannelAlreadyClosed => e
#     abort "ERROR: channel unexpectedly closed (#{e.inspect})"
#     # sleep 1
#     # retry
#   rescue Bunny::PreconditionFailed => e
#     abort "ERROR: precondition failed (#{e.inspect})"
#   rescue Interrupt => e
#     channel.close
#     conn.close
#     abort "QUITTING"
#   end
# end

# Dump configuration
# Hashie.symbolize_keys! config
