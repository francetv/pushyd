require 'bunny'
require "securerandom"

module PushyDaemon
  class EndpointConnexionContext    < StandardError; end
  class EndpointConnectionError     < StandardError; end
  class EndpointSubscribeContext    < StandardError; end
  class EndpointSubscribeError      < StandardError; end

  class Endpoint
    include Shared::LoggerHelper
    attr_reader :logger

    def initialize
      # Prepare logger
      init_logger Conf[:logs]

      # Done
      log_info "endpoint initialized"
    end

  protected

    def init_logger logconf
      # Check structure conformity or set it to an empty hash
      logconf = {} unless logconf.is_a? Hash
      loglevel  = logconf[:level]
      me        = self.class.name

      # Compute logfile
      logfile = logfile(logconf, :file)

      # Prepare logger (may be NIL > won't output anything)
      @logger = Logger.new(logfile, LOG_ROTATION)
      @logger.formatter = Shared::LoggerFormatter

      # Set progname
      @logger.progname = me.split('::').last

      # Set expected level
      @logger.level = case loglevel
      when "debug"
        Logger::DEBUG
      when "info"
        Logger::INFO
      when "warn"
        Logger::WARN
      else
        Logger::INFO
      end

      # Announce on STDOUT we're now logging to file
      if logfile
        puts "#{self.class} logging loglevel [#{loglevel} > #{@logger.level}] to [#{logfile}]"
      else
        puts "#{self.class} logging disabled"
      end
    end

    def log_message msg_way, msg_exchange, msg_key, msg_body = [], msg_attrs = {}
      # Message header
      info sprintf("%3s %-15s %s", msg_way, msg_exchange, msg_key)

      # Body lines
      if msg_body.is_a?(Enumerable) && !msg_body.empty?
        body_json = JSON.pretty_generate(msg_body)
        log_debug nil, body_json.lines
      end

      # Attributes lines
      log_debug nil, msg_attrs if msg_attrs
    end

    # Start connexion to RabbitMQ
    def connect_channel busconf
      fail PushyDaemon::EndpointConnexionContext, "invalid bus host/port" unless busconf
      info "connecting to #{busconf}"
      conn = Bunny.new busconf.to_s,
        logger: @logger,
        # heartbeat: :server,
        automatically_recover: true,
        network_recovery_interval: AMQP_RECOVERY_INTERVAL,
        heartbeat_interval: AMQP_HEARTBEAT_INTERVAL
      conn.start


      # Create channel, prefetch only one message at a time
      channel = conn.create_channel
      channel.prefetch(AMQP_PREFETCH)

    rescue Bunny::TCPConnectionFailedForAllHosts, Bunny::AuthenticationFailureError, AMQ::Protocol::EmptyResponseError  => e
      fail PushyDaemon::EndpointConnectionError, "error connecting (#{e.class})"
    rescue StandardError => e
      fail PushyDaemon::EndpointConnectionError, "unknow (#{e.inspect})"
    else
      return channel
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
      rule_queue = "#{Conf.app_name}-#{rule[:name]}"
      fail PushyDaemon::EndpointSubscribeContext, "rule [#{rule_name}] lacking topic" unless rule_topic
      fail PushyDaemon::EndpointSubscribeContext, "rule [#{rule_name}] lacking routes" if rule_routes.empty?

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
        # ["rule", "topic", "route", "relay", "queue", "description"]
        @table.add_row [rule_name, rule_topic, route, rule[:relay].to_s, rule_queue, rule[:title].to_s ]
      end

      # Subscribe to our new queue
      queue.subscribe(block: false, manual_ack: PROXY_USE_ACK, message_max: PROXY_MESSAGE_MAX) do |delivery_info, metadata, payload|

        # Handle the message
        handle_message rule, delivery_info, metadata, payload

      end

    rescue Bunny::PreconditionFailed => e
      fail PushyDaemon::EndpointSubscribeError, "PreconditionFailed: [#{rule_topic}] code(#{e.channel_close.reply_code}) message(#{e.channel_close.reply_text})"

    rescue StandardError => e
      fail PushyDaemon::EndpointSubscribeError, "unhandled (#{e.inspect})"

    end

    def handle_message rule, delivery_info, metadata, payload
    end

    def identifier len
      rand(36**len).to_s(36)
    end

  private

  end
end
