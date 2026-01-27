# frozen_string_literal: true

require "anthropic"

module OrchestraAI
  module Providers
    class Anthropic < Base
      MODELS = {
        "claude-opus-4-20250514" => { input: 15.0, output: 75.0, context: 200_000 },
        "claude-sonnet-4-20250514" => { input: 3.0, output: 15.0, context: 200_000 },
        "claude-3-5-haiku-latest" => { input: 0.80, output: 4.0, context: 200_000 }
      }.freeze

      def initialize(api_key: nil, model: nil)
        key = api_key || OrchestraAI.configuration.config.anthropic_api_key
        super(api_key: key, model: model)
        @client = ::Anthropic::Client.new(api_key: @api_key)
      end

      def complete(messages, **options)
        normalized = normalize_messages(messages)
        system_message = extract_system_message(normalized)
        user_messages = normalized.reject { |m| m[:role] == "system" }

        params = {
          model: effective_model,
          max_tokens: options[:max_tokens] || 4096,
          messages: user_messages
        }
        params[:system] = system_message if system_message
        params[:temperature] = options[:temperature] if options[:temperature]

        response = @client.messages.create(**params)

        build_response(
          content: extract_content(response),
          model: response.model,
          usage: {
            input_tokens: response.usage.input_tokens,
            output_tokens: response.usage.output_tokens
          },
          raw: response
        )
      rescue StandardError => e
        handle_error(e)
      end

      def stream(messages, **options, &block)
        normalized = normalize_messages(messages)
        system_message = extract_system_message(normalized)
        user_messages = normalized.reject { |m| m[:role] == "system" }

        params = {
          model: effective_model,
          max_tokens: options[:max_tokens] || 4096,
          messages: user_messages,
          stream: true
        }
        params[:system] = system_message if system_message
        params[:temperature] = options[:temperature] if options[:temperature]

        full_content = +""
        final_response = nil

        @client.messages.create(**params) do |event|
          case event.type
          when "content_block_delta"
            chunk = event.delta.text
            full_content << chunk
            block&.call(chunk)
          when "message_stop"
            final_response = event
          end
        end

        build_response(
          content: full_content,
          model: effective_model,
          usage: {}, # Usage not available in stream mode
          raw: final_response
        )
      rescue StandardError => e
        handle_error(e)
      end

      def provider_name
        :anthropic
      end

      def default_model
        "claude-sonnet-4-20250514"
      end

      def available_models
        MODELS.keys
      end

      def model_info(model_name = nil)
        MODELS[model_name || effective_model]
      end

      private

      def extract_system_message(messages)
        system_msg = messages.find { |m| m[:role] == "system" }
        system_msg&.fetch(:content, nil)
      end

      def extract_content(response)
        response.content.map { |block| block.text if block.respond_to?(:text) }.compact.join
      end
    end
  end
end
