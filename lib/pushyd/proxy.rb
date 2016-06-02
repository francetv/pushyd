require 'rest_client'
require 'bunny'
require 'yaml'
require 'json'
require 'terminal-table'

# Constants
PROXY_MESSAGE_MAX   = 1
PROXY_USE_ACK       = false
PROXY_SCOPE         = "dev"
# PROXY_IDENT = "proxy"
# QUEUE_HOST = `hostname`.to_s.chomp
# SEPARATOR  = "="*160
# ACK_PERCENT = 50


module PushyDaemon
  class Proxy

    attr_accessor :table

    def initialize(logger)
      @exchanges = {}
      @logger = logger

      # Init ASCII table
      @table = Terminal::Table.new
      @table.title = "Propagation rules"
      @table.headings = ["queue binding", "topic", "route", "relay", "title"]
      @table.align_column(5, :right)
    end

    def prepare
      # Start connexion to RabbitMQ and create channel
      conn = connect Config.bus
      @channel = conn.create_channel
      info "prepare: connected on a channel"

      # Check rules
      unless (Config.rules.is_a? Enumerable) && !Config.rules.empty?
        abort "prepare: empty [rules] section"
      end
      info "prepare: found [#{Config.rules.size}] rules"

      # Subsribe for each and every rule/route
      Config.rules.each do |name, rule|
        rule[:name] = name
        channel_subscribe rule
        #abort "prepare: OK"
      end

      # Send config table to logs
      info "prepare: dumping configuration\n#{@table.to_s}"
    end

    def main
      loop do
        info "ping"
        sleep(1)
      end
    end

  private

    def abort message
      @logger.error "ABORT: #{message}"
      raise "ABORT: #{message}"
    end

    def info message
      @logger.info message
    end

    def dump_rules rules

    end

    # Start connexion to RabbitMQ
    def connect busconf
      abort "connect: bus host/port not found" unless busconf.is_a? Hash

      puts "connecting to #{busconf[:host]} port #{busconf[:port]}"
      conn = Bunny.new host: (busconf[:host].to_s || "localhost").to_s,
        port: busconf[:port].to_i,
        user: busconf[:user].to_s,
        pass: busconf[:pass].to_s,
        heartbeat: :server
      conn.start
    rescue Bunny::TCPConnectionFailedForAllHosts, Bunny::AuthenticationFailureError, AMQ::Protocol::EmptyResponseError  => e
      abort "connect: error connecting to RabbitMQ (#{e.class})"
    rescue Exception => e
      abort "connect: unknow connection error (#{e.inspect})"
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
      abort "subscribe: rule [#{rule_name}] lacking topic" unless rule_topic
      abort "subscribe: rule [#{rule_name}] lacking routes" if rule_routes.empty?

      # Create queue for this rule (remove it beforehand)
      #conn.create_channel.queue_delete(rule_queue_name)
      queue = @channel.queue(rule_queue, auto_delete: false, durable: true)

      # Bind each route from this topic-exchange
      topic_exchange = channel_exchange(rule_topic)
      rule_routes.each do |route|
        # Bind exchange to queue
        queue.bind topic_exchange, routing_key: route
        info "subscribe: bind: \t[#{rule_topic}] \t[#{route}] \t> [#{rule_queue}]"

        # Add row to config table
        @table.add_row [rule_name, rule_topic, route, rule[:relay].to_s, rule[:title].to_s ]
      end

      # Subscribe to our new queue
      queue.subscribe(block: false, manual_ack: PROXY_USE_ACK, message_max: PROXY_MESSAGE_MAX) do |delivery_info, metadata, payload|

        # Handle the message
        handle_message rule[:name], rule, delivery_info, metadata, payload

      end

    rescue Bunny::PreconditionFailed => e
      abort "subscribe: PreconditionFailed: [#{rule_topic}] code(#{e.channel_close.reply_code}) message(#{e.channel_close.reply_text})"
    rescue Exception => e
      abort "subscribe: unhandled (#{e.inspect})"

    end

    # Handle the reception of a message on a queue
    def handle_message rule, delivery_info, metadata, payload
      # Prepare data
      rule_name = rule[:name]
      msg_topic = delivery_info.exchange
      msg_rkey = delivery_info.routing_key.force_encoding('UTF-8')
      msg_headers = metadata.headers || {}

      # Extract fields
      data = parse payload, metadata.content_type  #, rule

      # Announce match
      header rule_name, "<", msg_topic, msg_rkey

      # Build notification payload
      body = {
        # received: msg_topic,
        exchange: msg_topic,
        route: msg_rkey,
        #headers: msg_headers,
        sent_at: msg_headers['sent_at'],
        sent_by: msg_headers['sent_by'],
        data: data,
        }
      pretty_body = JSON.pretty_generate(body)

      # Dump body data
      puts "RULE: #{rule.inspect}"
      puts "APP-ID: #{metadata.app_id}"
      puts "CONTENT-TYPE: #{metadata.content_type}"
      puts pretty_body

      # Propagate data if needed
      #propagate rule[:relay], pretty_body
    end

    def propagate url, body
      # Nothing more to do if no relay
      return if url.nil? || url.empty?

      # Push message to URL
      puts "> POST #{url}"
      response = RestClient.post url.to_s, body, :content_type => :json
      puts "< #{response.body}"

      rescue Exception => e
        abort "propagate: #{e.message}"

    end


    def parse payload, content_type #, fields = []
      # Force encoding (pftop...)
      utf8payload = payload.force_encoding('UTF-8')

      # Parse payload if content-type provided
      case content_type
        when "application/json"
          # if fields = rule[:payload_extract]
          #   data = payload_extract(payload, fields)
          #   data_source = "extract #{fields.inspect} #{data.keys.count}k"
          return JSON.parse utf8payload

        when "text/plain"
          return utf8payload.to_s

        else
          return utf8payload
      end

      # Handle body parse errors
      rescue Encoding::UndefinedConversionError => e
        abort "parse: JSON PARSE ERROR: #{e.inspect}"
        return {}
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
