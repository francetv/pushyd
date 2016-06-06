module PushyDaemon
  class Daemon

    def self.run(logger)
      # Create a new proxy
      p = Proxy.new(logger)

      # Dump config table
      puts p.table.to_s

      # Create a new shouter
      s = Shouter.new(logger)

      # Start infinite loop
      s.shout
    end

  end
end
