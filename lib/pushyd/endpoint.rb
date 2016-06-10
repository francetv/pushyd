require 'bunny'
require "securerandom"

module PushyDaemon
  class EndpointConnexionContext    < StandardError; end
  class EndpointConnectionError     < StandardError; end
  class EndpointSubscribeContext    < StandardError; end
  class EndpointSubscribeError      < StandardError; end

  class Endpoint

    def initialize
      # Prepare logger
      init_logger Conf[:log]

      # OK
      info "endpoint initialized"

    end

  protected

    def init_logger logconf
      # Prepare logger (may be NIL > won't output anything)
      logfile = logconf[:file]
      loglevel = logconf[:level]
      @logger = Logger.new(logfile, LOG_ROTATION)

      # Set formatter
      @logger.formatter = Formatter

      # Set progname
      me = self.class.name
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

    def error messages
      @logger.error messages
    end

    def info messages
      @logger.info messages
    end

    def debug messages
      @logger.debug messages
    end

    def message params = {}
      # Header
      @logger.info sprintf(
        "%3s %-15s %s",
        params[:way],
        params[:exchange],
        params[:key]
        )

      # Attributes
      @logger.debug params[:attrs] if params[:attrs].is_a?(Hash)

      # Body (split in lines to log them separately)
      if params[:body].is_a?(Enumerable) && !params[:body].empty?
        body_json = JSON.pretty_generate(params[:body])
        #puts "log? #{params[:body]} "
        @logger.debug body_json.lines
      end
    end

    # Start connexion to RabbitMQ
    def connect_channel busconf
      fail PushyDaemon::EndpointConnexionContext, "invalid bus host/port" unless (busconf.is_a? Hash) &&
        busconf[:host] && busconf[:port]

      info "connecting to #{busconf[:host]} port #{busconf[:port]}"
      conn = Bunny.new host: (busconf[:host].to_s || "localhost").to_s,
        port: busconf[:port].to_i,
        user: busconf[:user].to_s,
        pass: busconf[:pass].to_s,
        heartbeat: :server
      conn.start

      # Create channel
      channel = conn.create_channel

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
      rule_queue = "#{Conf.name}-#{rule[:name]}"
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
        @table.add_row [rule_name, rule_topic, route, rule[:relay].to_s, rule[:title].to_s ]
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

  end
end
