require 'rest_client'
require 'yaml'
require 'json'
require 'terminal-table'

module PushyDaemon

  # class ProxyConnexionContext    < StandardError; end

  class Proxy < Endpoint

    attr_accessor :table

    def initialize(logger)
      # Init
      @exchanges = {}
      @logger = logger

      # Init ASCII table
      @table = Terminal::Table.new
      @table.title = "Propagation rules"
      @table.headings = ["queue binding", "topic", "route", "relay", "title"]
      @table.align_column(5, :right)

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

