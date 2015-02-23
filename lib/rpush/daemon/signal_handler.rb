module Rpush
  module Daemon
    class SignalHandler
      extend Loggable

      class << self
        attr_reader :thread
        attr_accessor :listen
      end

      def self.start
        return unless trap_signals?
        listen = true

        %w(INT TERM HUP USR2).each do |signal|
          Signal.trap(signal) do
            break unless listen
            @thread = Thread.new { start_handler signal }
          end
        end
      end

      def self.stop
        listen = false
        @thread.join if @thread
      rescue StandardError => e
        log_error(e)
        reflect(:error, e)
      ensure
        @thread = nil
      end

      def self.start_handler(signal)
        begin
          case signal
          when 'HUP' then handle_hup
          when 'USR2' then handle_usr2
          when 'INT', 'TERM'
            handle_shutdown_signal
            listen = false
          else
            Rpush.logger.error "Unhandled signal: #{signal}"
          end
        rescue StandardError => e
          Rpush.logger.error("Error raised when handling signal '#{signal}'")
          Rpush.logger.error(e)
        end
      end

      def self.handle_shutdown_signal
        Rpush.logger.info 'Received TERM/INT signal.'
        Thread.new { Rpush::Daemon.shutdown }
      end

      def self.handle_hup
        Rpush.logger.reopen
        Rpush.logger.info('Received HUP signal.')
        Rpush::Daemon.store.reopen_log
        Synchronizer.sync
        Feeder.wakeup
      end

      def self.handle_usr2
        Rpush.logger.info('Received USR2 signal.')
        AppRunner.debug
      end

      def self.trap_signals?
        !Rpush.config.embedded
      end
    end
  end
end
