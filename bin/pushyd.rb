#!/usr/bin/env ruby

# Try to load external libs, helpers and constants
begin
  require "rubygems"
  require "optparse"
  require 'daemons'
  require 'logger'
  require_relative "../lib/pushyd/config"
rescue LoadError
  raise "EXITING: some basic libs were not found"
end

# Guess app root
APP_ROOT = File.expand_path(File.dirname(__FILE__) + "/../")

# Parse options and check compliance
cmd_config = nil
cmd_env = "production"
cmd_dump = false
begin
  OptionParser.new do |opts|
    opts.banner = "Usage: #{File.basename $PROGRAM_NAME} [options] start|stop"
    opts.on("-c", "--config CONFIGFILE")     { |config| cmd_config = File.expand_path(config)}
    opts.on("-e", "--environment ENV")       { |env| cmd_env = env }
    opts.on("-d", "--dump")                  { cmd_dump = true }
    opts.on("",   "--dev")                   { cmd_env = "development" }
  end.order!(ARGV)
rescue OptionParser::InvalidOption => e
  abort "EXITING: option parser: #{e.message}"
end


# Build Chamber-based configuration from Gemspec with initial context
Config.prepare root: APP_ROOT, gemspec: "pushyd", env: cmd_env, config: cmd_config

# Display final configuration
puts "--- #{Config.name} #{Config.version}"
puts "Environment    \t #{Config.env}"
puts "Config files   \t #{Config.files}"
puts
puts "Log file       \t #{Config[:log]}"
puts Config.dump if cmd_dump


# Run daemon
run_options = {
  ontop: false,
  # :dir_mode   => :normal,
  # :dir        => File.join(root, 'amine.log'),
  # :log_output => true,
  :backtrace  => true,
  :multiple   => false
  }
Daemons.run_proc('pushy-daemon', run_options) do
  # Load code
  puts "--- loading code and logger"
  require_relative "../lib/pushyd"

  # Prepare logger
  if Config[:log]
    logger = Logger.new(Config[:log])
    logger.info('Daemon starting')
  end

  # Start daemon
  puts "--- starting"
  PushyDaemon::Daemon.run(logger)
end
