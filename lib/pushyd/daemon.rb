module PushyDaemon
  class Daemon

    def self.run
      # Create a new proxy
      p = Proxy.new

      # Dump config table
      puts p.table.to_s

      # Create a new shouter
      s = Shouter.new

      # Start infinite loop
      s.shout

    rescue Errno::EACCES, Exception => e
      abort "EXITING #{e.class}: #{e.message}"

    end

  end
end
