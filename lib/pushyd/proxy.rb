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
      info "connected on a channel"

      # Check rules
      unless (Config.rules.is_a? Enumerable) && !Config.rules.empty?
        abort "prepare: empty [rules] section"
      end
      info "found rules: #{config_rules.keys.join(', ')}"

      # Subsribe for each and every rule/route
      Config.rules.each do |name, rule|
        rule[:name] = name
        channel_subscribe rule
        #abort "prepare: OK"
      end

      # Send config table to logs
      info "dumping configuration\n#{@table.to_s}"

    def main
      loop do
        info "ping"
        sleep(1)
      end
    rescue Bunny::TCPConnectionFailedForAllHosts => e
      abort "ERROR: cannot connect to RabbitMQ hosts (#{e.inspect})"
    end

  private

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
      message way: WAY_IN,
        exchange: msg_exchange,
        key: msg_rkey,
        body: data,
        attrs: {
          'rule' => rule_name,
          'app-id' => metadata.app_id,
          'content-type' => metadata.content_type,
        }

      # Build notification payload
      body = {
        # received: msg_topic,
        exchange: msg_topic,
        route: msg_rkey,
        sent_at: msg_headers['sent_at'],
        sent_by: msg_headers['sent_by'],
        data: data,
        }

      # Propagate data if needed
      #propagate rule[:relay], pretty_body
    end

    def propagate url, body
      # Nothing more to do if no relay
      return if url.nil? || url.empty?
      id = SecureRandom.random_number(100)

      # Log message details
      message way: WAY_POST,
        exchange: id,
        key: relay_url,
        body: post_body

      # Push message to URL
      response = RestClient.post url.to_s, body, :content_type => :json
      info "#{id}: #{response.body}"

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

