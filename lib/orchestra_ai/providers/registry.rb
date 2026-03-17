# frozen_string_literal: true

module OrchestraAI
  module Providers
    class Registry
      # All models now use the unified RubyLLM provider
      MODEL_TO_PROVIDER = {
        # Google Gemini models
        'gemini-3.1-pro-preview' => :google,
        'gemini-3-flash-preview' => :google,
        'gemini-2.5-flash' => :google,
        'gemini-2.5-flash-lite' => :google,
        'gemini-2.5-pro' => :google,

        # OpenAI GPT-5 family models
        'gpt-5.4' => :openai,
        'gpt-5-mini' => :openai,
        'gpt-5-nano' => :openai,
        'gpt-4.1' => :openai,
        'o4-mini' => :openai,

        # Anthropic Claude models
        'claude-opus-4.6' => :anthropic,
        'claude-sonnet-4.6' => :anthropic,
        'claude-haiku-4.5' => :anthropic,

        # Mistral models
        'mistral-small-latest' => :mistral,
        'mistral-medium-latest' => :mistral,
        'mistral-large-latest' => :mistral
      }.freeze

      class << self
        def get(_provider_name)
          # All providers now use the unified RubyLLM provider
          RubyLLMProvider
        end

        def for_model(model_name)
          provider_name = MODEL_TO_PROVIDER[model_name]
          raise ProviderNotFoundError, "Unknown model: #{model_name}" unless provider_name

          RubyLLMProvider
        end

        def create(_provider_name, **options)
          RubyLLMProvider.new(**options)
        end

        def create_for_model(model_name, **options)
          raise ProviderNotFoundError, "Unknown model: #{model_name}" unless MODEL_TO_PROVIDER[model_name]

          RubyLLMProvider.new(model: model_name, **options)
        end

        def available_providers
          %i[anthropic openai google mistral].select do |provider|
            OrchestraAI.configuration.provider_available?(provider)
          end
        end

        def all_models
          MODEL_TO_PROVIDER.keys
        end

        def models_for_provider(provider_name)
          MODEL_TO_PROVIDER.select { |_, p| p == provider_name.to_sym }.keys
        end

        def provider_for_model(model_name)
          MODEL_TO_PROVIDER[model_name]
        end

        def model_available?(model_name)
          provider = provider_for_model(model_name)
          return false unless provider

          OrchestraAI.configuration.provider_available?(provider)
        end
      end
    end
  end
end
