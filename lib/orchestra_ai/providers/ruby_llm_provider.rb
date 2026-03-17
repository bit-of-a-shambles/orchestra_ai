# frozen_string_literal: true

require 'ruby_llm'

module OrchestraAI
  module Providers
    # Unified provider using RubyLLM for all AI models
    class RubyLLMProvider < Base
      # Model pricing per 1M tokens (input/output)
      MODELS = {
        # Google Gemini
        'gemini-3.1-pro-preview' => { input: 2.00, output: 12.00, context: 1_000_000, provider: :gemini },
        'gemini-3-flash-preview' => { input: 0.50, output: 3.00, context: 1_000_000, provider: :gemini },
        'gemini-2.5-flash' => { input: 0.30, output: 2.50, context: 1_000_000, provider: :gemini },
        'gemini-2.5-flash-lite' => { input: 0.10, output: 0.40, context: 1_000_000, provider: :gemini },
        'gemini-2.5-pro' => { input: 1.25, output: 10.00, context: 1_000_000, provider: :gemini },

        # OpenAI GPT-5 family
        'gpt-5.4' => { input: 2.50, output: 15.00, context: 1_000_000, provider: :openai },
        'gpt-5-mini' => { input: 0.25, output: 2.00, context: 400_000, provider: :openai },
        'gpt-5-nano' => { input: 0.05, output: 0.40, context: 400_000, provider: :openai },
        'gpt-4.1' => { input: 2.00, output: 8.00, context: 1_000_000, provider: :openai },
        'o4-mini' => { input: 1.10, output: 4.40, context: 200_000, provider: :openai },

        # Anthropic Claude 4.6
        'claude-opus-4.6' => { input: 5.00, output: 25.00, context: 200_000, provider: :anthropic },
        'claude-sonnet-4.6' => { input: 3.00, output: 15.00, context: 200_000, provider: :anthropic },
        'claude-haiku-4.5' => { input: 1.00, output: 5.00, context: 200_000, provider: :anthropic }
      }.freeze

      def initialize(model: nil)
        @model = model
        configure_ruby_llm
      end

      def complete(messages, **options)
        normalized = normalize_messages(messages)

        chat = RubyLLM.chat(model: effective_model)

        # Add system message if present
        system_msg = normalized.find { |m| m[:role] == 'system' }
        chat.with_instructions(system_msg[:content]) if system_msg

        # Build conversation from messages
        user_messages = normalized.reject { |m| m[:role] == 'system' }

        response = nil
        user_messages.each do |msg|
          if msg[:role] == 'user'
            response = chat.ask(msg[:content])
          elsif msg[:role] == 'assistant'
            # Add assistant context
            chat.messages << RubyLLM::Message.new(role: :assistant, content: msg[:content])
          end
        end

        build_response(
          content: response.content,
          model: effective_model,
          usage: extract_usage(response),
          raw: response
        )
      rescue StandardError => e
        handle_error(e)
      end

      def stream(messages, **options, &block)
        normalized = normalize_messages(messages)

        chat = RubyLLM.chat(model: effective_model)

        # Add system message if present
        system_msg = normalized.find { |m| m[:role] == 'system' }
        chat.with_instructions(system_msg[:content]) if system_msg

        # Get last user message
        user_messages = normalized.reject { |m| m[:role] == 'system' }
        last_user_msg = user_messages.reverse.find { |m| m[:role] == 'user' }

        full_content = +''
        response = chat.ask(last_user_msg[:content]) do |chunk|
          if chunk.content
            full_content << chunk.content
            block&.call(chunk.content)
          end
        end

        build_response(
          content: full_content,
          model: effective_model,
          usage: extract_usage(response),
          raw: response
        )
      rescue StandardError => e
        handle_error(e)
      end

      def provider_name
        model_info = MODELS[effective_model]
        model_info ? model_info[:provider] : :unknown
      end

      def default_model
        'gemini-2.5-flash'
      end

      def available_models
        MODELS.keys
      end

      def model_info(model_name = nil)
        MODELS[model_name || effective_model]
      end

      private

      def effective_model
        @model || default_model
      end

      def configure_ruby_llm
        config = OrchestraAI.configuration

        RubyLLM.configure do |c|
          c.openai_api_key = config.openai_api_key if config.openai_api_key
          c.anthropic_api_key = config.anthropic_api_key if config.anthropic_api_key
          c.gemini_api_key = config.google_api_key if config.google_api_key
        end
      end

      def extract_usage(response)
        return {} unless response.respond_to?(:input_tokens)

        {
          input_tokens: response.input_tokens || 0,
          output_tokens: response.output_tokens || 0
        }
      end
    end
  end
end
