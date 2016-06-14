module PushyDaemon
  class Formatter

    def self.call severity, datetime, progname, payload
      # Build common values
      timestamp = datetime.strftime(LOG_FORMAT_TIME)

      # Build header
      header = sprintf LOG_FORMAT_HEADER,
        timestamp,
        Process.pid,
        severity,
        progname

      # If we have a bunch of lines, prefix them and send them together
      return payload.map do |line|
        "#{header}#{trimmed(line)}\n"
      end.join if payload.is_a?(Array)

      # Otherwise, just prefix the only line
      return "#{header}#{trimmed(payload)}\n"
    end

  protected

    def self.trimmed line
      line.to_s.rstrip[0..LOG_TRIM_LINE].force_encoding(Encoding::UTF_8)
    end

  end
end
