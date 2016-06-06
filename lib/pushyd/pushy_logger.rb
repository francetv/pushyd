require "logger"

class PushyLogger < Logger

  def initialize logfile, rotation = nil
    # Call my parent's initializer
    super

    # And the formatter
    self.formatter = proc do |severity, datetime, progname, messages|
      # Build common line prefix
      prefix = "%s %s\t" % [
        datetime.strftime(LOG_FORMAT_TIME),
        severity      ]

      # If we have a bunch of lines, prefix them and send them together
      if messages.is_a? Array
        messages.map { |line| prefix + line + LOG_NEWLINE}.join
      else
        prefix + messages.to_s + LOG_NEWLINE
      end
    end
  end

  def add level, message, lines = {}
    level ||= Logger::DEBUG

    prefix = "   | "

    if lines.is_a? Hash
      output = build_from_hash prefix, lines
    elsif lines.is_a? Array
      output = build_from_array prefix, lines
    else
      output = []
    end

    # Prepend plain message to output
    output.unshift message.force_encoding(Encoding::UTF_8)

    # Send all this to logger
    super level, output
  end

protected

  def build_from_array prefix, lines
    lines.map do |value|
      text = value.to_s[0..LOG_TRIM_LINE]
      "#{prefix}#{text}"
    end
  end

  def build_from_hash prefix, lines
    lines.map do |name, value|
      text = value.to_s.strip[0..LOG_TRIM_LINE]
      "#{prefix}#{name}: #{text}"
    end
  end

end
