# frozen_string_literal: true

module OrchestraAI
  module Providers
    class Base
      attr_reader :api_key, :model

      def initialize(api_key:, model: nil)
        @api_key = api_key
        @model = model
        validate_api_key!
      end

      # Execute a completion request
      # @param messages [Array<Hash>] Array of message hashes with :role and :content
      # @param options [Hash] Provider-specific options (temperature, max_tokens, etc.)
      # @return [Hash] Response with :content, :model, :usage, :raw
      def complete(messages, **options)
        raise NotImplementedError, "#{self.class} must implement #complete"
      end

      # Stream a completion request
      # @param messages [Array<Hash>] Array of message hashes with :role and :content
      # @param options [Hash] Provider-specific options
      # @yield [String] Yields content chunks as they arrive
      # @return [Hash] Final response with :content, :model, :usage
      def stream(messages, **options, &block)
        raise NotImplementedError, "#{self.class} must implement #stream"
      end

      # Provider identifier
      def provider_name
        raise NotImplementedError, "#{self.class} must implement #provider_name"
      end

      # Check if provider is available
      def available?
        !api_key.nil? && !api_key.empty?
      end

      # Default model for this provider
      def default_model
        raise NotImplementedError, "#{self.class} must implement #default_model"
      end

      # List of available models
      def available_models
        raise NotImplementedError, "#{self.class} must implement #available_models"
      end

      protected

      def validate_api_key!
        return if api_key && !api_key.empty?

        raise MissingApiKeyError, "API key required for #{provider_name}"
      end

      def effective_model
        model || default_model
      end

      def normalize_messages(messages)
        messages.map do |msg|
          {
            role: msg[:role]&.to_s || msg["role"],
            content: msg[:content] || msg["content"]
          }
        end
      end

      def build_response(content:, model:, usage:, raw:)
        {
          content: content,
          model: model,
          usage: usage,
          raw: raw,
          provider: provider_name,
          timestamp: Time.now.utc
        }
      end

      def handle_error(error)
        case error
        when Faraday::TimeoutError
          raise ProviderTimeoutError.new(
            "Request timed out",
            provider: provider_name,
            original_error: error
          )
        when Faraday::UnauthorizedError
          raise ProviderAuthenticationError.new(
            "Authentication failed",
            provider: provider_name,
            original_error: error
          )
        when Faraday::TooManyRequestsError
          raise ProviderRateLimitError.new(
            "Rate limit exceeded",
            provider: provider_name,
            original_error: error
          )
        else
          raise ProviderError.new(
            error.message,
            provider: provider_name,
            original_error: error
          )
        end
      end
    end
  end
end
