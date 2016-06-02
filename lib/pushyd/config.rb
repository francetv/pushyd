require "chamber"

class Config
  extend Chamber

  class << self
    attr_reader :name
    attr_reader :spec
    attr_reader :files
    attr_reader :version
    attr_reader :env
  end

  def self.prepare args = {}
    # Context parameters
    raise "config: missing root" unless (@root = args[:root])
    raise "config: missing env"  unless (@env = args[:env])

    # Gemspec parameter
    gemspec_path = "#{args[:root]}/#{args[:gemspec]}.gemspec"
    raise "config: missing gemspec" unless args[:gemspec]
    raise "config: missing gemspec file at #{gemspec_path}" unless File.exist?(gemspec_path)

    # Load Gemspec
    @spec     = Gem::Specification::load gemspec_path
    @name     = @spec.name
    @version  = @spec.version
    raise "config: missing name" unless @name

    # Init Chamber (defaults, etc, cmdline)
    @files = ["#{args[:root]}/defaults.yml"]
    @files << File.expand_path("/etc/#{@name}.yml")
    @files << args[:config].to_s if args[:config]

    # Load configuration files
    load files: @files, namespaces: { environment: @env }
  end

  def self.dump
    self.to_hash.to_yaml
  end

end
