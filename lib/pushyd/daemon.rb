module PushyDaemon
  class Daemon

    def self.run(logger)
      # Create a new proxy
      p = Proxy.new(logger)

      # Prepare subscriptions
      p.prepare

      # Make it listen

      # Dump config table
      puts p.table.to_s

      # Start infinite loop
      p.main
    end

  end
end
