# frozen_string_literal: true

require "openai"

module OrchestraAI
  module Providers
    class OpenAI < Base
      MODELS = {
        "gpt-4o" => { input: 2.50, output: 10.0, context: 128_000 },
        "gpt-4o-mini" => { input: 0.15, output: 0.60, context: 128_000 },
        "gpt-4-turbo" => { input: 10.0, output: 30.0, context: 128_000 },
        "o1" => { input: 15.0, output: 60.0, context: 200_000 },
        "o1-mini" => { input: 3.0, output: 12.0, context: 128_000 }
      }.freeze

      def initialize(api_key: nil, model: nil)
        key = api_key || OrchestraAI.configuration.config.openai_api_key
        super(api_key: key, model: model)
        @client = ::OpenAI::Client.new(access_token: @api_key)
      end

      def complete(messages, **options)
        normalized = normalize_messages(messages)

        params = {
          model: effective_model,
          messages: normalized
        }
        params[:max_tokens] = options[:max_tokens] if options[:max_tokens]
        params[:temperature] = options[:temperature] if options[:temperature]

        response = @client.chat(parameters: params)

        if response["error"]
          raise ProviderError.new(
            response["error"]["message"],
            provider: provider_name
          )
        end

        choice = response.dig("choices", 0)

        build_response(
          content: choice.dig("message", "content"),
          model: response["model"],
          usage: {
            input_tokens: response.dig("usage", "prompt_tokens"),
            output_tokens: response.dig("usage", "completion_tokens")
          },
          raw: response
        )
      rescue StandardError => e
        handle_error(e)
      end

      def stream(messages, **options, &block)
        normalized = normalize_messages(messages)

        params = {
          model: effective_model,
          messages: normalized,
          stream: true
        }
        params[:max_tokens] = options[:max_tokens] if options[:max_tokens]
        params[:temperature] = options[:temperature] if options[:temperature]

        full_content = +""

        @client.chat(parameters: params) do |chunk|
          delta = chunk.dig("choices", 0, "delta", "content")
          if delta
            full_content << delta
            block&.call(delta)
          end
        end

        build_response(
          content: full_content,
          model: effective_model,
          usage: {},
          raw: nil
        )
      rescue StandardError => e
        handle_error(e)
      end

      def provider_name
        :openai
      end

      def default_model
        "gpt-4o"
      end

      def available_models
        MODELS.keys
      end

      def model_info(model_name = nil)
        MODELS[model_name || effective_model]
      end
    end
  end
end
