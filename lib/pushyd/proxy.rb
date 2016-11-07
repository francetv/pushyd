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
      @table.title = "Propagation rules"
      @table.headings = ["rule", "topic", "route", "relay", "created queue", "description"]
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


      rescue BmcDaemonLib::MqConsumerException, EndpointConnectionError, ShouterInterrupted, Errno::EACCES => e
        log_error "Proxy: #{e.message}"
        abort "EXITING #{e.class}: #{e.message}"

      rescue StandardError => e
        log_error "Proxy: #{e.message}", e.backtrace
        abort "EXITING #{e.class}: #{e.message} \n #{e.backtrace.to_yaml}"

        raise MqConsumerException, e.message

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

      # Subscribe for each and every rule/route
      config_rules.each do |name, rule|
        rule[:name] = name
        create_consumer rule
      end
    end

    # Subscribe to interesting topic/routes and bind a listenner
    def create_consumer rule
      # Check information
      rule_name   = rule[:name].to_s
      rule_topic  = rule[:topic].to_s
      rule_routes = rule[:routes].to_s.split(' ')
      rule_queue  = sprintf('%s-%s', BmcDaemonLib::Conf.app_name, rule_name.gsub('_', '-'))

      fail PushyDaemon::EndpointSubscribeContext, "rule [#{rule_name}] lacking topic" unless rule_topic
      fail PushyDaemon::EndpointSubscribeContext, "rule [#{rule_name}] lacking routes" if rule_routes.empty?

      # Build a new consumer
      consumer = Consumer.new(@conn, rule_name, rule)

      # Create its own queue
      consumer.subscribe_to_queue rule_queue, "rule:#{rule_name}"

      # Bind each route to exchange
      rule_routes.each do |route|
        consumer.listen_to rule_topic, route

        # Add row to config table
        @table.add_row [rule_name, rule_topic, route, rule[:relay].to_s, rule_queue, rule[:title].to_s ]
      end

      # Return it
      @consumers << consumer
    end

    def consumer_cancelled all={}
      log_error "consumer_cancelled remotely: #{all.inspect}"
    end

  end
end
