# frozen_string_literal: true

require 'test_helper'

class ConfigurationTest < Minitest::Test
  include OrchestraAITestHelper

  def test_has_default_model_settings
    config = OrchestraAI::Configuration.new

    assert_equal 'gemini-2.5-flash', config.models.architect.simple
    assert_equal 'gpt-5.4', config.models.architect.moderate
    assert_equal 'claude-opus-4.6', config.models.architect.complex
  end

  def test_has_default_difficulty_thresholds
    config = OrchestraAI::Configuration.new

    assert_equal 0.33, config.difficulty.simple_threshold
    assert_equal 0.66, config.difficulty.moderate_threshold
  end

  def test_has_default_retry_settings
    config = OrchestraAI::Configuration.new

    assert_equal 3, config.retry_config.max_attempts
    assert_equal 1.0, config.retry_config.base_delay
  end

  def test_provider_available_returns_false_when_no_api_key
    config = OrchestraAI::Configuration.new
    config.anthropic_api_key = nil

    refute config.provider_available?(:anthropic)
  end

  def test_provider_available_returns_true_when_api_key_set
    config = OrchestraAI::Configuration.new
    config.anthropic_api_key = 'test-key'

    assert config.provider_available?(:anthropic)
  end

  def test_validate_raises_when_no_api_keys_configured
    config = OrchestraAI::Configuration.new
    config.anthropic_api_key = nil
    config.openai_api_key = nil
    config.google_api_key = nil

    assert_raises(OrchestraAI::ConfigurationError) do
      config.validate!
    end
  end

  def test_validate_returns_true_when_valid
    config = OrchestraAI::Configuration.new
    config.anthropic_api_key = 'test-key'

    assert config.validate!
  end

  def test_provider_available_returns_false_for_unknown_provider
    config = OrchestraAI::Configuration.new

    refute config.provider_available?(:unknown_provider)
  end

  def test_has_default_development_settings
    config = OrchestraAI::Configuration.new

    refute config.development.enabled
    assert config.development.coding_cli_enabled
    assert config.development.copilot_instructions_enabled
    assert_equal %w[codex opencode pi claude], config.development.coding_cli_order
    assert_equal %i[implementer reviewer], config.development.coding_cli_roles
  end
end
