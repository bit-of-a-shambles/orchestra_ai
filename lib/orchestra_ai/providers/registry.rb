# frozen_string_literal: true

module OrchestraAI
  module Providers
    class Registry
      PROVIDERS = {
        anthropic: Anthropic,
        openai: OpenAI,
        google: Google
      }.freeze

      MODEL_TO_PROVIDER = {
        # Anthropic models
        "claude-opus-4-20250514" => :anthropic,
        "claude-sonnet-4-20250514" => :anthropic,
        "claude-3-5-haiku-latest" => :anthropic,
        # OpenAI models
        "gpt-4o" => :openai,
        "gpt-4o-mini" => :openai,
        "gpt-4-turbo" => :openai,
        "o1" => :openai,
        "o1-mini" => :openai,
        # Google models
        "gemini-2.5-pro-preview-05-06" => :google,
        "gemini-2.0-flash" => :google,
        "gemini-2.0-flash-lite" => :google
      }.freeze

      class << self
        def get(provider_name)
          provider_class = PROVIDERS[provider_name.to_sym]
          raise ProviderNotFoundError.new("Unknown provider: #{provider_name}") unless provider_class

          provider_class
        end

        def for_model(model_name)
          provider_name = MODEL_TO_PROVIDER[model_name]
          raise ProviderNotFoundError.new("Unknown model: #{model_name}") unless provider_name

          get(provider_name)
        end

        def create(provider_name, **options)
          get(provider_name).new(**options)
        end

        def create_for_model(model_name, **options)
          provider_class = for_model(model_name)
          provider_class.new(model: model_name, **options)
        end

        def available_providers
          PROVIDERS.keys.select do |provider|
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
