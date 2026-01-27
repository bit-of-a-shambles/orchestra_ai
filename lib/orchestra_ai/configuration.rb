# frozen_string_literal: true

require "dry-configurable"

module OrchestraAI
  class Configuration
    extend Dry::Configurable

    # API Keys
    setting :anthropic_api_key, default: ENV.fetch("ANTHROPIC_API_KEY", nil)
    setting :openai_api_key, default: ENV.fetch("OPENAI_API_KEY", nil)
    setting :google_api_key, default: ENV.fetch("GOOGLE_API_KEY", nil)

    # Model defaults by role and complexity tier
    setting :models do
      setting :architect do
        setting :simple, default: "claude-3-5-haiku-latest"
        setting :moderate, default: "claude-sonnet-4-20250514"
        setting :complex, default: "claude-opus-4-20250514"
      end

      setting :implementer do
        setting :simple, default: "gemini-2.0-flash"
        setting :moderate, default: "gemini-2.5-pro-preview-05-06"
        setting :complex, default: "claude-sonnet-4-20250514"
      end

      setting :reviewer do
        setting :simple, default: "gpt-4o-mini"
        setting :moderate, default: "gpt-4o"
        setting :complex, default: "claude-opus-4-20250514"
      end
    end

    # Difficulty scoring thresholds
    setting :difficulty do
      setting :simple_threshold, default: 0.33
      setting :moderate_threshold, default: 0.66
    end

    # Retry policy
    setting :retry do
      setting :max_attempts, default: 3
      setting :base_delay, default: 1.0
      setting :max_delay, default: 30.0
      setting :multiplier, default: 2.0
    end

    # Circuit breaker
    setting :circuit_breaker do
      setting :failure_threshold, default: 5
      setting :reset_timeout, default: 60
    end

    # Parallel execution
    setting :parallel do
      setting :max_threads, default: 4
      setting :timeout, default: 300
    end

    # Logging
    setting :logger, default: nil
    setting :log_level, default: :info

    def validate!
      errors = []

      if config.anthropic_api_key.nil? && config.openai_api_key.nil? && config.google_api_key.nil?
        errors << "At least one API key must be configured"
      end

      raise ConfigurationError, errors.join(", ") unless errors.empty?

      true
    end

    def provider_available?(provider)
      case provider.to_sym
      when :anthropic then !config.anthropic_api_key.nil?
      when :openai then !config.openai_api_key.nil?
      when :google then !config.google_api_key.nil?
      else false
      end
    end
  end
end
