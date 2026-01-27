# frozen_string_literal: true

require "concurrent"

module OrchestraAI
  module Reliability
    class CircuitBreaker
      STATES = %i[closed open half_open].freeze

      attr_reader :name, :state, :failure_count, :last_failure_time

      def initialize(
        name:,
        failure_threshold: nil,
        reset_timeout: nil
      )
        config = OrchestraAI.configuration.config.circuit_breaker
        @name = name
        @failure_threshold = failure_threshold || config.failure_threshold
        @reset_timeout = reset_timeout || config.reset_timeout
        @state = :closed
        @failure_count = Concurrent::AtomicFixnum.new(0)
        @last_failure_time = Concurrent::AtomicReference.new(nil)
        @mutex = Mutex.new
      end

      # Execute a block with circuit breaker protection
      def execute(&block)
        check_state!

        begin
          result = block.call
          on_success
          result
        rescue StandardError => e
          on_failure(e)
          raise
        end
      end

      # Check if circuit is allowing requests
      def allow_request?
        case state
        when :closed
          true
        when :open
          should_attempt_reset?
        when :half_open
          true
        end
      end

      # Reset the circuit breaker
      def reset
        @mutex.synchronize do
          @state = :closed
          @failure_count.value = 0
          @last_failure_time.value = nil
        end
      end

      # Force the circuit open
      def trip!
        @mutex.synchronize do
          @state = :open
          @last_failure_time.value = Time.now
        end
      end

      def open?
        state == :open
      end

      def closed?
        state == :closed
      end

      def half_open?
        state == :half_open
      end

      private

      def check_state!
        if open?
          if should_attempt_reset?
            transition_to(:half_open)
          else
            raise CircuitOpenError.new(
              "Circuit breaker '#{name}' is open",
              provider: name,
              reset_at: reset_at
            )
          end
        end
      end

      def on_success
        @mutex.synchronize do
          @failure_count.value = 0
          @state = :closed if half_open?
        end
      end

      def on_failure(error)
        @mutex.synchronize do
          @failure_count.increment
          @last_failure_time.value = Time.now

          if @failure_count.value >= @failure_threshold
            @state = :open
            OrchestraAI.logger.warn(
              "Circuit breaker '#{name}' opened after #{@failure_count.value} failures"
            )
          end
        end
      end

      def should_attempt_reset?
        return false unless last_failure_time.value

        Time.now - last_failure_time.value >= @reset_timeout
      end

      def reset_at
        return nil unless last_failure_time.value

        last_failure_time.value + @reset_timeout
      end

      def transition_to(new_state)
        @mutex.synchronize do
          @state = new_state
        end
      end
    end

    # Manages circuit breakers for all providers
    class CircuitBreakerRegistry
      class << self
        def instance
          @instance ||= new
        end

        def for_provider(provider_name)
          instance.get_or_create(provider_name)
        end

        def reset_all
          instance.reset_all
        end
      end

      def initialize
        @breakers = Concurrent::Map.new
      end

      def get_or_create(name)
        @breakers.compute_if_absent(name.to_sym) do
          CircuitBreaker.new(name: name)
        end
      end

      def reset_all
        @breakers.each_value(&:reset)
      end
    end
  end
end
