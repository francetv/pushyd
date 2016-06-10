require 'rest_client'
require 'terminal-table'

module PushyDaemon
  class Proxy < Endpoint

    attr_accessor :table

    def initialize
      # Init
      super
      @exchanges = {}

      # Init ASCII table
      @table = Terminal::Table.new
      @table.title = "Propagation rules"
      @table.headings = ["rule", "topic", "route", "relay", "queue", "description"]
      @table.align_column(5, :right)

      # Start connexion to RabbitMQ and create channel
      @channel = connect_channel Conf.bus
      info "channel connected"

      # Check config
      config_rules = Conf[:rules]
      unless (config_rules.is_a? Enumerable) && !config_rules.empty?
        error "prepare: empty [rules] section"
      end
      info "found rules: #{config_rules.keys.join(', ')}"

      # Subsribe for each and every rule/route
      config_rules.each do |name, rule|
        rule[:name] = name
        channel_subscribe rule
        #abort "prepare: OK"
      end

      # Send config table to logs
      table_lines = @table.to_s.lines
      info "initialized with configuration:", table_lines

    rescue Bunny::TCPConnectionFailedForAllHosts => e
      error "ERROR: cannot connect to RabbitMQ hosts (#{e.inspect})"
    end

  private

    # Handle the reception of a message on a queue
    def handle_message rule, delivery_info, metadata, payload
      # Prepare data
      rule_name = rule[:name]
      rule_relay = rule[:relay]
      msg_exchange = delivery_info.exchange
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
      post_body = {
        exchange: msg_exchange,
        route: msg_rkey,
        sent_at: msg_headers['sent_at'],
        sent_by: msg_headers['sent_by'],
        data: data,
        }

      # Propagate data if needed
      propagate rule_relay, post_body if rule_relay
    end

    def propagate relay_url, post_body
      # Nothing more to do if no relay
      return if relay_url.nil? || relay_url.empty?
      id = SecureRandom.random_number(100)

      # Log message details
      message way: WAY_POST,
        exchange: id,
        key: relay_url,
        body: post_body

      # Push message to URL
      response = RestClient.post relay_url.to_s, JSON.pretty_generate(post_body), :content_type => :json
      info "#{id}: #{response.body}"

      rescue StandardError => e
        error "propagate: #{e.message}"
    end


    def parse payload, content_type #, fields = []
      # Force encoding (pftop...)
      utf8payload = payload.to_s.force_encoding('UTF-8')

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
      error "parse: JSON PARSE ERROR: #{e.inspect}"
      return {}
    end

  end
end
