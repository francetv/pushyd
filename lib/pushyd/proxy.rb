require "bunny"
require 'api_auth'
require 'rest_client'
require 'terminal-table'

module PushyDaemon
  class Proxy < BmcDaemonLib::MqEndpoint
    #include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation

    # Class options
    attr_accessor :table

    def initialize
      # Init
      @shouter = nil
      @consumers = []

      # Init ASCII table
      @table = Terminal::Table.new
      @table.title = "Rules summary"
      @table.headings = ["rule", "topic", "> queue", "> relay", "routing key", "bind status"]
      @table.align_column(5, :right)

      # Prepare logger
      @logger = BmcDaemonLib::LoggerPool.instance.get

      # Start connexion to RabbitMQ
      @conn = connect_to BmcDaemonLib::Conf[:broker]
      log_info "Proxy connected"

      # Create a new shouter
      @shouter = create_shouter

      # Check config and subscribe rules
      create_consumers

      # Send config table to logs
      log_info "Proxy initialized", @table.to_s
      puts @table.to_s

      # Make the shouter loop!
      @shouter.start_loop

      rescue BmcDaemonLib::MqConsumerException => e
        log_error "Proxy consumer: #{e.message}"
        abort "EXITING #{e.class}: #{e.message}"

      rescue ShouterInterrupted, EndpointConnectionError, Errno::EACCES => e
        log_error "Proxy error: #{e.message}"
        abort "EXITING #{e.class}: #{e.message}"

      rescue StandardError => e
        log_error "Proxy unexpected: #{e.message}", e.backtrace
        abort "EXITING #{e.class}: #{e.message} \n #{e.backtrace.to_yaml}"
        # raise MqConsumerException, e.message

    end

  protected

    def log_context
      {
        me: :proxy
      }

    end

    def create_shouter
      # Get config
      config_shouter = BmcDaemonLib::Conf[:shout]

      # Create the shouter
      Shouter.new(@conn, config_shouter)
    end

    def create_consumers
      # Get config
      config_rules = BmcDaemonLib::Conf[:rules]
      if config_rules.nil? || !config_rules.is_a?(Hash)
        log_error "create_consumers: no rules"
        return
      end
      log_info "create_consumers: #{config_rules.keys.join(', ')}"

      # Subscribe for each and every rule/key
      config_rules.each do |name, rule|
        rule[:name] = name
        @consumers << create_consumer(rule)
      end
    end

    # Subscribe to interesting topic/key and bind a listenner
    def create_consumer rule
      # Check information
      rule_name   = rule[:name].to_s
      rule_topic  = rule[:topic].to_s
      rule_queue  = sprintf('%s-%s', BmcDaemonLib::Conf.app_name, rule_name.gsub('_', '-'))

      # Extract routing keys
      if rule[:keys].is_a? Array
        rule_keys = rule[:keys].map(&:to_s)
      else
        rule_keys = rule[:keys].to_s.split(',').map(&:strip)
      end

      # Check we have a topic and at least one routing key
      fail PushyDaemon::EndpointSubscribeContext, "rule [#{rule_name}] lacking topic" unless rule_topic
      fail PushyDaemon::EndpointSubscribeContext, "rule [#{rule_name}] lacking keys" if rule_keys.empty?

      # Build a new consumer
      consumer = Consumer.new(@conn, rule_name, rule)

      # Subscribe to my own queue
      consumer.subscribe_to_queue rule_queue, "rule:#{rule_name}"

      # Bind each key to exchange
      rule_keys.each do |key|
        begin
          status = "> #{rule_queue}"
        rescue BmcDaemonLib::MqConsumerTopicNotFound => e
          status = "! BIND FAILED"
          log_error "Proxy consumer: #{e.message}"
          q = consumer.listen_to rule_topic, key
        end

        # Add row to config table
        @table.add_row [rule_name, rule_topic, rule_queue, rule[:relay].to_s, key, status ]
      end

      # Return consumer
      consumer
    end

    def consumer_cancelled all={}
      log_error "consumer_cancelled remotely: #{all.inspect}"
    end

  end
end
