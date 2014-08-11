module Rpush
  module Daemon
    class SignalHandler

      def self.start
        return unless trap_signals?

        %w(INT TERM HUP USR2).each do |signal|
          Signal.trap(signal) {
            Thread.new { start_handler(signal) }
          }
        end
      end

      def self.start_handler(signal)
        Rpush.logger.info "Trapped signal #{signal}."

        case signal
        when 'HUP'
          Synchronizer.sync
          Feeder.wakeup
        when 'USR2'
          AppRunner.debug
        when 'INT', 'TERM'
          handle_shutdown_signal
        else
          # This should never happen, but hey, who knows?
          Rpush.logger.warn "Caught unknown signal: #{signal}."
        end
      end

      def self.handle_shutdown_signal
        Rpush::Daemon.shutdown
      end

      def self.trap_signals?
        !Rpush.config.embedded
      end
    end
  end
end
