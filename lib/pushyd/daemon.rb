module PushyDaemon
  class Daemon

    def self.run(logger)
      loop do
        logger.info "ping"
        sleep(1)
      end
    end

  end
end
