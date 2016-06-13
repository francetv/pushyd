require "chamber"

module PushyDaemon
  class ConfigMissingParameter    < StandardError; end
  class ConfigOtherError          < StandardError; end
  class ConfigParseError          < StandardError; end
  class ConfigMultipleGemspec          < StandardError; end
  class ConfigMissingGemspec          < StandardError; end

  class Conf
    extend Chamber

    class << self
      attr_accessor :app_env

      attr_reader :app_root
      attr_reader :app_name
      attr_reader :app_ver

      attr_reader :spec
      attr_reader :files
      attr_reader :host

    end

    def self.init app_root = nil
      # Defaults, hostname
      @files    = []
      @app_env  = "production"
      @host     = `hostname`.to_s.chomp.split(".").first

      # Gemspec parameter
      gemspec_path = "#{args[:root]}/#{args[:gemspec]}.gemspec"
      fail PushyDaemon::ConfigMissingParameter, "missing gemspec" unless args[:gemspec]
      fail PushyDaemon::ConfigMissingParameter, "gemspec file not found: #{gemspec_path}" unless File.exist?(gemspec_path)


      # Load Gemspec
      @spec     = Gem::Specification::load gemspec_path
      @app_name = @spec.name
      @app_ver  = @spec.version
      fail ConfigMissingParameter, "gemspec: missing name" unless @app_name
      fail ConfigMissingParameter, "gemspec: missing version" unless @app_ver

      # Add config files
      add_default_config
      add_etc_config
    end

    def self.prepare args = {}
      # Add extra config file
      add_extra_config args[:config]

      # Load configuration files
      load files: @files, namespaces: { environment: @env }

      # Init New Relic
      prepare_newrelic self[:newrelic]

      # Try to access any key to force parsing of the files
      self[:dummy]

    rescue Psych::SyntaxError => e
      fail PushyDaemon::ConfigParseError, e.message
    rescue StandardError => e
      fail PushyDaemon::ConfigOtherError, "#{e.message} \n #{e.backtrace.to_yaml}"
    end

    def self.dump
      self.to_hash.to_yaml
    end

    def Conf.newrelic_enabled?
      !!self[:newrelic]
    end

  protected

    def self.add_default_config
      @files << "#{@app_root}/defaults.yml" if @app_root
    end

    def self.add_etc_config
      @files << File.expand_path("/etc/#{@name}.yml") if @name
    end

    def self.add_extra_config path
      @files << File.expand_path("/etc/#{@name}.yml") if path
    end

    def self.prepare_newrelic section
      unless section.is_a?(Hash)
        # puts "prepare_newrelic: no config found"
        ENV["NEWRELIC_AGENT_ENABLED"] = "false"
        return
      end
      # puts "prepare_newrelic: #{section.inspect}"

      # Enable GC profiler
      GC::Profiler.enable

      # Enable module
      ENV["NEWRELIC_AGENT_ENABLED"] = "true"
      ENV["NEW_RELIC_MONITOR_MODE"] = "true"

      # License
      ENV["NEW_RELIC_LICENSE_KEY"] = section[:licence].to_s

      # Appname
      platform = section[:platform] || self.host
      section[:app_name] ||= "#{self.name}-#{platform}-#{self.app_env}"
      ENV["NEW_RELIC_APP_NAME"] = section[:app_name].to_s

      # Logfile
      ENV["NEW_RELIC_LOG"] = section[:logfile].to_s
    end


  end
end
