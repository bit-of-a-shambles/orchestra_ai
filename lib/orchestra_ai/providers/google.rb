# frozen_string_literal: true

require "gemini-ai"

module OrchestraAI
  module Providers
    class Google < Base
      MODELS = {
        "gemini-2.5-pro-preview-05-06" => { input: 1.25, output: 10.0, context: 1_000_000 },
        "gemini-2.0-flash" => { input: 0.10, output: 0.40, context: 1_000_000 },
        "gemini-2.0-flash-lite" => { input: 0.075, output: 0.30, context: 1_000_000 }
      }.freeze

      def initialize(api_key: nil, model: nil)
        key = api_key || OrchestraAI.configuration.config.google_api_key
        super(api_key: key, model: model)
        @client = Gemini.new(
          credentials: { service: "generative-language-api", api_key: @api_key },
          options: { model: effective_model }
        )
      end

      def complete(messages, **options)
        normalized = normalize_messages(messages)
        contents = build_contents(normalized)

        config = {}
        config[:maxOutputTokens] = options[:max_tokens] if options[:max_tokens]
        config[:temperature] = options[:temperature] if options[:temperature]

        response = @client.generate_content(
          { contents: contents },
          generation_config: config.empty? ? nil : config
        )

        content = extract_content(response)

        build_response(
          content: content,
          model: effective_model,
          usage: extract_usage(response),
          raw: response
        )
      rescue StandardError => e
        handle_error(e)
      end

      def stream(messages, **options, &block)
        normalized = normalize_messages(messages)
        contents = build_contents(normalized)

        config = {}
        config[:maxOutputTokens] = options[:max_tokens] if options[:max_tokens]
        config[:temperature] = options[:temperature] if options[:temperature]

        full_content = +""

        @client.stream_generate_content(
          { contents: contents },
          generation_config: config.empty? ? nil : config
        ) do |chunk|
          text = chunk.dig("candidates", 0, "content", "parts", 0, "text")
          if text
            full_content << text
            block&.call(text)
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
        :google
      end

      def default_model
        "gemini-2.0-flash"
      end

      def available_models
        MODELS.keys
      end

      def model_info(model_name = nil)
        MODELS[model_name || effective_model]
      end

      private

      def build_contents(messages)
        # Extract system message for system instruction
        system_msg = messages.find { |m| m[:role] == "system" }
        user_messages = messages.reject { |m| m[:role] == "system" }

        contents = user_messages.map do |msg|
          role = msg[:role] == "assistant" ? "model" : "user"
          { role: role, parts: [{ text: msg[:content] }] }
        end

        # Prepend system message as user context if present
        if system_msg
          contents.unshift(
            { role: "user", parts: [{ text: "System: #{system_msg[:content]}" }] },
            { role: "model", parts: [{ text: "Understood. I will follow these instructions." }] }
          )
        end

        contents
      end

      def extract_content(response)
        response.dig("candidates", 0, "content", "parts", 0, "text") || ""
      end

      def extract_usage(response)
        metadata = response["usageMetadata"] || {}
        {
          input_tokens: metadata["promptTokenCount"],
          output_tokens: metadata["candidatesTokenCount"]
        }
      end
    end
  end
end
