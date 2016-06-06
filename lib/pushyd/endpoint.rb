require 'bunny'
require 'securerandom'

module PushyDaemon

  class EndpointConnexionContext    < StandardError; end
  class EndpointConnectionError     < StandardError; end
  class EndpointSubscribeContext    < StandardError; end
  class EndpointSubscribeError      < StandardError; end

  class Endpoint

    def initialize
      # Prepare logger (may be NIL > won't output anything)
      logfile = Config[:log]

      # Create the logger
      @logger = PushyLogger.new(logfile, LOG_ROTATION)
      @logger.add Logger::INFO, "starting #{self.class.name.to_s}"
    end

  protected

    def error message
      @logger.add Logger::ERROR, "#{self.class}: #{message}"
      #raise "ABORT #{self.class}: #{message}"
    end

    def info message
      @logger.add Logger::INFO, "#{self.class}: #{message}"
    end

    def message params = {}
      # Indenting
      #indent = " " * (params[:way].length)
      lines = []

      # Header
      message = sprintf(
        "%3s %-15s %s",
        params[:way],
        params[:exchange],
        params[:key]
        )

      # Attributes
      if (params[:attrs].is_a? Hash)
        # lines.merge params[:attrs]
        params[:attrs].each do |name, value|
          lines << sprintf("%-15s %s", name, value)
        end
      end

      # Body (split in lines to log them separately)
      unless (params[:body].nil? || params[:body].empty?)
        JSON.pretty_generate(params[:body]).each_line do |line|
          lines << line.rstrip
        end
      end

      # Send the info
      @logger.add Logger::INFO, message, lines
      # @logger.log_info message, lines
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
