require "logger"

module Shared
  module LoggerHelper
    CONFIG_PATH = :path

    def logfile config, pipe
      # Disabled if no valid config
      return nil unless config.is_a?(Hash)

      # Compute logfile and check if we can write there
      logfile = File.expand_path(config[pipe].to_s, config[CONFIG_PATH].to_s)

      # Check that we'll be able to create logfiles
      if File.exists?(logfile)
        # File is there, is it writable ?
        unless File.writable?(logfile)
          puts "LoggerHelper [#{pipe}] disabled: file not writable [#{logfile}]"
          return nil
        end
      else
        # No file here, can we create it ?
        logdir = File.dirname(logfile)
        unless File.writable?(logdir)
          puts "LoggerHelper [#{pipe}] disabled: directory not writable [#{logdir}]"
          return nil
        end
      end

      # OK, return a clean file path
      puts "LoggerHelper [#{pipe}] logging to [#{logfile}]"
      return logfile
    end

  protected

    def log_info message, details = nil
      build_messages Logger::INFO, message, details
    end

    def log_error message, details = nil
      build_messages Logger::ERROR, message, details
    end

    def log_debug message, details = nil
      build_messages Logger::DEBUG, message, details
    end

    alias info log_info
    alias error log_error
    alias debug log_debug

  private

    # Builds prefix if LOG_PREFIX_FORMAT defined and caller has log_prefix method to provide values
    def build_prefix
      # Skip if no values from user class
      return unless respond_to?(:log_prefix, true)
      values = log_prefix

      # Skip if no format defined
      return unless defined?('LOG_PREFIX_FORMAT')
      return unless LOG_PREFIX_FORMAT.is_a? String

      # Build prefix string
      LOG_PREFIX_FORMAT % values.map(&:to_s)
    end

    def build_messages severity, message, details = nil
      messages = []

      prefix = build_prefix

      # Add main message
      messages << sprintf(LOG_MESSAGE_TEXT, prefix, message) if message

      # Add details from array
      details.each do |line|
        messages << sprintf(LOG_MESSAGE_ARRAY, prefix, line)
      end if details.is_a? Array

      # Add details from hash
      details.each do |key, value|
        messages << sprintf(LOG_MESSAGE_HASH, prefix, key, value)
      end if details.is_a? Hash

      # Return all that stuff
      # messages << "\\---------------------------------------"
      logger.add severity, messages
    end

  end
end
