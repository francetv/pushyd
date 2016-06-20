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
      @table.headings = ["rule", "topic", "route", "relay", "created queue", "description"]
      @table.align_column(5, :right)

      # Start connexion to RabbitMQ and create channel
      @channel = connect_channel Conf.bus
      info "channel connected"

      # Check config
      config_rules = Conf[:rules]
      if config_rules.nil? || !config_rules.is_a?(Hash)
        error "prepare: empty [rules] section"
      else
        info "found rules: #{config_rules.keys.join(', ')}"

        # Subsribe for each and every rule/route
        config_rules.each do |name, rule|
          rule[:name] = name
          channel_subscribe rule
        end
      end

      # Send config table to logs
      info "proxy initialized", @table.to_s.lines

    rescue Bunny::TCPConnectionFailedForAllHosts => e
      error "ERROR: cannot connect to RabbitMQ hosts (#{e.inspect})"
    end

  protected

    def log_prefix
      ['proxy']
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
      log_message MSG_RECV, msg_exchange, msg_rkey, data, {
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
      log_message WAY_PROP, id, relay_url, post_body

      # Push message to URL
      response = RestClient.post relay_url.to_s, JSON.pretty_generate(post_body), :content_type => :json
      info "#{id}: #{response.body}"

      rescue StandardError => e
        error "propagate: #{e.message}"
    end

  private

    def parse payload, content_type #, fields = []
      # Force encoding (pftop...)
      utf8payload = payload.to_s.force_encoding('UTF-8')

      # Parse payload if content-type provided
      case content_type
        when "application/json"
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

    # NewRelic instrumentation
    if Conf.newrelic_enabled?
      include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
      add_transaction_tracer :handle_message, category: :task
      add_transaction_tracer :propagate,      category: :task
    end

  end
end
