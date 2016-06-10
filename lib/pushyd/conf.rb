require "chamber"

module PushyDaemon
  class ConfigMissingParameter    < StandardError; end
  class ConfigParseError          < StandardError; end

  class Conf
    extend Chamber

    class << self
      attr_reader :name
      attr_reader :spec
      attr_reader :files
      attr_reader :version
      attr_reader :env
      attr_reader :host
    end

    def self.prepare args = {}
      # Context parameters
      fail PushyDaemon::ConfigMissingParameter, "missing root" unless (@root = args[:root])
      fail PushyDaemon::ConfigMissingParameter, "missing env"  unless (@env = args[:env])

      # Gemspec parameter
      gemspec_path = "#{args[:root]}/#{args[:gemspec]}.gemspec"
      fail PushyDaemon::ConfigMissingParameter, "missing gemspec" unless args[:gemspec]
      fail PushyDaemon::ConfigMissingParameter, "gemspec file not found: #{gemspec_path}" unless File.exist?(gemspec_path)

      # Init host if missing
      @host ||= `hostname`.to_s.chomp.split(".").first

      # Load Gemspec
      @spec     = Gem::Specification::load gemspec_path
      @name     = @spec.name
      @version  = @spec.version
      fail PushyDaemon::ConfigMissingParameter, "missing name" unless @name

      # Init Chamber (defaults, etc, cmdline)
      @files = ["#{args[:root]}/defaults.yml"]
      @files << File.expand_path("/etc/#{@name}.yml")
      @files << args[:config].to_s if args[:config]

      # Load configuration files
      load files: @files, namespaces: { environment: @env }

      # Try to access any key to force parsing of the files
      self[:dummy]

      # Override some values
      self[:log] = args[:log].to_s if args[:log]

    rescue Psych::SyntaxError => e
      fail PushyDaemon::ConfigParseError, e.message
    rescue Exception => e
      fail PushyDaemon::ConfigParseError, e.message
    end

    def self.dump
      self.to_hash.to_yaml
    end

  end
end
