# frozen_string_literal: true

module OrchestraAI
  module Testing
    class MockProvider < Providers::Base
      attr_accessor :responses, :calls

      def initialize(responses: nil)
        @api_key = "test-api-key"
        @model = "mock-model"
        @responses = Array(responses || ["Mock response"])
        @response_index = 0
        @calls = []
      end

      def complete(messages, **options)
        record_call(:complete, messages, options)
        response = next_response

        build_response(
          content: response,
          model: @model,
          usage: { input_tokens: 10, output_tokens: 20 },
          raw: { mock: true }
        )
      end

      def stream(messages, **options, &block)
        record_call(:stream, messages, options)
        response = next_response

        # Simulate streaming by yielding chunks
        response.chars.each_slice(10) do |chunk|
          block&.call(chunk.join)
        end

        build_response(
          content: response,
          model: @model,
          usage: { input_tokens: 10, output_tokens: 20 },
          raw: { mock: true, streamed: true }
        )
      end

      def provider_name
        :mock
      end

      def default_model
        "mock-model"
      end

      def available_models
        ["mock-model"]
      end

      # Queue a specific response
      def queue_response(response)
        @responses << response
        self
      end

      # Queue an error
      def queue_error(error)
        @responses << error
        self
      end

      # Clear call history
      def clear_calls
        @calls = []
        self
      end

      # Get the last call made
      def last_call
        @calls.last
      end

      # Check if a specific message was sent
      def received_message?(content)
        @calls.any? do |call|
          call[:messages].any? { |m| m[:content]&.include?(content) }
        end
      end

      protected

      def validate_api_key!
        # No validation needed for mock
      end

      private

      def record_call(method, messages, options)
        @calls << {
          method: method,
          messages: messages,
          options: options,
          timestamp: Time.now.utc
        }
      end

      def next_response
        response = @responses[@response_index % @responses.size]
        @response_index += 1

        if response.is_a?(Exception)
          raise response
        end

        response
      end
    end
  end
end
