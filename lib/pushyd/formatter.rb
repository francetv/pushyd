module PushyDaemon
  class Formatter

    def self.call severity, datetime, progname, messages
      # Build common values
      timestamp = datetime.strftime(LOG_FORMAT_TIME)

      # If we have a bunch of lines, prefix them and send them together
      if messages.is_a? Array
        messages.map do |line|
          sprintf LOG_FORMAT_ARRAY, timestamp, severity, progname, trimmed(line)
        end.join

      elsif messages.is_a? Hash
        messages.map do |key, value|
          sprintf LOG_FORMAT_HASH, timestamp, severity, progname, key, value
        end.join

      else
        sprintf LOG_FORMAT_LINE, timestamp, severity, progname, trimmed(messages)

      end
    end

  protected

    def self.trimmed line
      line.to_s.rstrip[0..LOG_TRIM_LINE].force_encoding(Encoding::UTF_8)
    end

  end
end
