# frozen_string_literal: true

module OrchestraAI
  module Reliability
    class RetryPolicy
      RETRYABLE_ERRORS = [
        ProviderRateLimitError,
        ProviderTimeoutError,
        Faraday::TimeoutError,
        Faraday::ConnectionFailed
      ].freeze

      attr_reader :max_attempts, :base_delay, :max_delay, :multiplier

      def initialize(
        max_attempts: nil,
        base_delay: nil,
        max_delay: nil,
        multiplier: nil
      )
        config = OrchestraAI.configuration.config.retry
        @max_attempts = max_attempts || config.max_attempts
        @base_delay = base_delay || config.base_delay
        @max_delay = max_delay || config.max_delay
        @multiplier = multiplier || config.multiplier
      end

      # Execute a block with retry logic
      # @yield Block to execute
      # @return Result of the block
      def execute(&block)
        attempt = 0
        last_error = nil

        loop do
          attempt += 1

          begin
            return block.call
          rescue *RETRYABLE_ERRORS => e
            last_error = e

            if attempt >= max_attempts
              raise e
            end

            delay = calculate_delay(attempt)
            OrchestraAI.logger.warn(
              "Retry #{attempt}/#{max_attempts} after #{e.class}: #{e.message}. " \
              "Waiting #{delay.round(2)}s"
            )
            sleep(delay)
          end
        end
      end

      # Wrap a provider with retry logic
      def wrap(provider)
        RetryWrapper.new(provider, self)
      end

      private

      def calculate_delay(attempt)
        delay = base_delay * (multiplier**(attempt - 1))
        jitter = delay * rand(0.0..0.1)
        [delay + jitter, max_delay].min
      end
    end

    class RetryWrapper
      def initialize(provider, policy)
        @provider = provider
        @policy = policy
      end

      def complete(messages, **options)
        @policy.execute { @provider.complete(messages, **options) }
      end

      def stream(messages, **options, &block)
        @policy.execute { @provider.stream(messages, **options, &block) }
      end

      def method_missing(method, *args, **kwargs, &block)
        if @provider.respond_to?(method)
          @provider.send(method, *args, **kwargs, &block)
        else
          super
        end
      end

      def respond_to_missing?(method, include_private = false)
        @provider.respond_to?(method, include_private) || super
      end
    end
  end
end
