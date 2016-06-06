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

    rescue Errno::EACCES => e
      #logger.error "ABORT #{e.class}: #{e.message}"
      abort "ABORT #{e.class}: #{e.message}"

    rescue Exception => e
      #logger.error "ABORT #{e.class}: #{e.message}"
      abort "ABORT #{e.class}: #{e.message}"

    end

  end
end
