require 'api_auth'
require 'rest_client'
require 'terminal-table'

module PushyDaemon
    include Shared::HmacSignature
  class Proxy < BmcDaemonLib::MqEndpoint
    #include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation

    # Class options
    attr_accessor :table

    def initialize
      # Init
      @exchanges = {}
      @shouters = []

      # Init ASCII table
      @table = Terminal::Table.new
      @table.title = "Propagation rules"
      @table.headings = ["rule", "topic", "route", "relay", "created queue", "description"]
      @table.align_column(5, :right)

      # Prepare logger
      @logger = BmcDaemonLib::LoggerPool.instance.get

      # Check config
      config_rules = Conf[:rules]
      if config_rules.nil? || !config_rules.is_a?(Hash)
        log_error "prepare: empty [rules] section"
      else
        log_info "found rules: #{config_rules.keys.join(', ')}"

        # Subsribe for each and every rule/route
        config_rules.each do |name, rule|
          rule[:name] = name
          channel_subscribe rule
        end
      end
      # Start connexion to RabbitMQ
      @conn = connect_to BmcDaemonLib::Conf[:broker]
      log_info "Proxy connected"

      # Create a new shouter, and start its loop
      create_shouter

      # Send config table to logs
      log_info "Proxy initialized", @table.to_s.lines
    end

  protected

  private

    def extract_delay msg_headers
      return unless msg_headers['sent_at']
    def create_shouter
      # Get config
      config_shouter = BmcDaemonLib::Conf[:shout]

      # Extract sent_at header
      sent_at = Time.iso8601(msg_headers['sent_at']) rescue nil
      # log_info "sent_at     : #{sent_at.to_f}"
      # log_info "timenow     : #{Time.now.to_f}"
      # Create the shouter
      shouter = Shouter.new(@conn, config_shouter)
      @shouters << shouter

      # Compute delay
      return ((Time.now - sent_at)*1000).round(2)
      # Now make it loop
      shouter.start_loop
    end


    # Handle the reception of a message on a queue
    def handle_message rule, delivery_info, metadata, payload
      # Prepare data
      rule_name = rule[:name]
      msg_exchange = delivery_info.exchange
      msg_rkey = delivery_info.routing_key.force_encoding('UTF-8')
      msg_headers = metadata.headers || {}

      # Compute delay and size
      delay = extract_delay(msg_headers)
      size = format_bytes(payload.bytesize, "B")

      # Extract payload
      data = parse payload, metadata.content_type

      # Announce match
      log_message MSG_RECV, msg_exchange, msg_rkey, data, {
        'matched rule' => rule_name,
        'app-id' => metadata.app_id,
        'content-type' => metadata.content_type,
        'delay (ms)' => delay,
        'body size' => size,
        }

      # Build notification payload
      propagate_data = {
        exchange: msg_exchange,
        route: msg_rkey,
        sent_at: msg_headers['sent_at'],
        sent_by: msg_headers['sent_by'],
        data: data,
        }

      # Propagate data if needed
      propagate rule, propagate_data
    end

    def propagate rule, data
      # Nothing more to do if no relay
      return if rule[:relay].nil? || rule[:relay].empty?

      # Prepare stuff
      relay_auth = rule[:auth].to_s
      relay_uri = URI(rule[:relay])
      relay_url = relay_uri.to_s
      id = identifier(6)
      # log_info "propagate: user[#{relay_uri.user}] url[#{relay_url}]"

      # Build POST body and log message
      post_body = JSON.pretty_generate(data)
      log_message WAY_PROP, id, relay_url, data

      # Prepare request
      request = RestClient::Request.new url: relay_url,
        method: :post,
        payload: post_body,
        headers: {
          content_type: :json,
          accept: :json,
          user_agent: Conf.generate(:user_agent),
          }

      # Compute payload MD5
      headers_md5 request

      # Compute HMAC signature
      headers_sign request, rule['hmac-method'], rule['hmac-user'], rule['hmac-secret'], [:date]

      # Send request
      log_info "propagate: #{relay_url}", request.headers
      response = request.execute

      # Handle exceptions
      rescue RestClient::ExceptionWithResponse, URI::InvalidURIError => e
        log_error "propagate: rest-client: #{e.message}"
      rescue RestClient::InternalServerError => e
        log_error "propagate: rest-client: #{e.message}"
      rescue ApiAuth::ApiAuthError, ApiAuth::UnknownHTTPRequest => e
        log_error "propagate: api-auth: #{e.message}"
      rescue Errno::ECONNREFUSED => e
        log_error "propagate: connection refused: #{e.message}"
      rescue StandardError => e
        log_error "propagate: unknown: #{e.message}, #{e.inspect}", e.backtrace
      else
        log_info "propagate: #{response.body}"
    end

    def parse payload, content_type #, fields = []
      # Force encoding (pftop...)
      utf8payload = payload.to_s.force_encoding('UTF-8')

      # Parse payload if content-type provided
      case content_type
        when "application/json"
          return JSON.parse utf8payload rescue nil
        when "text/plain"
          return utf8payload.to_s
        else
          return utf8payload
      end

    # Handle body parse errors
    rescue Encoding::UndefinedConversionError => e
      log_error "parse: JSON PARSE ERROR: #{e.inspect}"
      return {}
    end

    # NewRelic instrumentation
    add_transaction_tracer :handle_message, category: :task
    add_transaction_tracer :propagate,      category: :task

  end
end
