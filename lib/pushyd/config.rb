require "chamber"

class Config
  extend Chamber

  def self.from options = {}

    # Check parameters
    return unless options[:root] && options[:env]

    # Init Chamber
    configs = ["#{options[:root]}/defaults.yml"]
    configs << options[:def_config].to_s if options[:def_config]
    configs << options[:cmd_config].to_s if options[:cmd_config]

    # Display context
    puts "Configuration  \t #{configs.join(', ')}"
    puts "Environment   \t #{options[:env]}"

    # Load configuration files
    load files: configs, namespaces: { environment: options[:env] }
  end

  def self.dump
    self.to_hash.to_yaml
  end

end
