# frozen_string_literal: true

module QA
  module Support
    module Retrier
      extend Repeater

      module_function

      def retry_on_exception(max_attempts: 3, reload_page: nil, sleep_interval: 0.5, log: true)
        if log
          msg = ["with retry_on_exception: max_attempts: #{max_attempts}"]
          msg << "reload_page: #{reload_page}" if reload_page
          msg << "sleep_interval: #{sleep_interval}"
          QA::Runtime::Logger.debug(msg.join('; '))
        end

        result = nil
        repeat_until(
          max_attempts: max_attempts,
          reload_page: reload_page,
          sleep_interval: sleep_interval,
          retry_on_exception: true,
          log: log
        ) do
          result = yield

          # This method doesn't care what the return value of the block is.
          # We set it to `true` so that it doesn't repeat if there's no exception
          true
        end
        QA::Runtime::Logger.debug("ended retry_on_exception") if log

        result
      end

      def retry_until(
        max_attempts: nil,
        max_duration: nil,
        reload_page: nil,
        sleep_interval: 0,
        raise_on_failure: true,
        retry_on_exception: false,
        log: true
      )
        # For backwards-compatibility
        max_attempts = 3 if max_attempts.nil? && max_duration.nil?

        if log
          start_msg = ["with retry_until:"]
          start_msg << "max_attempts: #{max_attempts};" if max_attempts
          start_msg << "max_duration: #{max_duration};" if max_duration
          start_msg.push(*[
                           "reload_page: #{reload_page};",
                           "sleep_interval: #{sleep_interval};",
                           "raise_on_failure: #{raise_on_failure};",
                           "retry_on_exception: #{retry_on_exception}"
                         ])

          QA::Runtime::Logger.debug(start_msg.join(' '))
        end

        result = nil
        repeat_until(
          max_attempts: max_attempts,
          max_duration: max_duration,
          reload_page: reload_page,
          sleep_interval: sleep_interval,
          raise_on_failure: raise_on_failure,
          retry_on_exception: retry_on_exception,
          log: log
        ) do
          result = yield
        end
        QA::Runtime::Logger.debug("ended retry_until") if log

        result
      end
    end
  end
end
