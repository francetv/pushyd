module PushyDaemon
  class Daemon

    def self.run
      # Create a new proxy, and dump its configuration
      Proxy.new

      # Backup infinite loop in case shout does nothing
      loop do
        sleep 1
      end

    rescue EndpointConnectionError, ShouterInterrupted => e
      abort "EXITING #{e.class}: #{e.message}"
    rescue Errno::EACCES, StandardError => e
      abort "EXITING #{e.class}: #{e.message} \n #{e.backtrace.to_yaml}"
    end

  end
end
