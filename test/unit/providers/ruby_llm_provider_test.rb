# frozen_string_literal: true

require 'test_helper'

class RubyLLMProviderTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure do |c|
      c.anthropic_api_key = 'test-key'
      c.openai_api_key = 'test-key'
      c.google_api_key = 'test-key'
    end
  end

  def test_initialise_without_model
    provider = OrchestraAI::Providers::RubyLLMProvider.new

    assert_equal 'gemini-2.5-flash', provider.default_model
  end

  def test_initialise_with_model
    provider = OrchestraAI::Providers::RubyLLMProvider.new(model: 'gpt-4.1')

    assert_equal 'gpt-4.1', provider.instance_variable_get(:@model)
  end

  def test_provider_name_returns_correct_provider
    provider = OrchestraAI::Providers::RubyLLMProvider.new(model: 'claude-opus-4.5')

    assert_equal :anthropic, provider.provider_name
  end

  def test_provider_name_for_openai_model
    provider = OrchestraAI::Providers::RubyLLMProvider.new(model: 'gpt-4.1')

    assert_equal :openai, provider.provider_name
  end

  def test_provider_name_for_gemini_model
    provider = OrchestraAI::Providers::RubyLLMProvider.new(model: 'gemini-2.5-flash')

    assert_equal :gemini, provider.provider_name
  end

  def test_provider_name_returns_unknown_for_invalid_model
    provider = OrchestraAI::Providers::RubyLLMProvider.new(model: 'invalid-model')

    assert_equal :unknown, provider.provider_name
  end

  def test_default_model_returns_gemini_flash
    provider = OrchestraAI::Providers::RubyLLMProvider.new

    assert_equal 'gemini-2.5-flash', provider.default_model
  end

  def test_available_models_returns_all_models
    provider = OrchestraAI::Providers::RubyLLMProvider.new

    models = provider.available_models

    assert_includes models, 'gemini-2.5-flash'
    assert_includes models, 'gpt-4.1'
    assert_includes models, 'claude-opus-4.5'
  end

  def test_model_info_returns_pricing_info
    provider = OrchestraAI::Providers::RubyLLMProvider.new

    info = provider.model_info('claude-opus-4.5')

    assert_equal 5.00, info[:input]
    assert_equal 25.00, info[:output]
    assert_equal 200_000, info[:context]
  end

  def test_model_info_without_arg_uses_effective_model
    provider = OrchestraAI::Providers::RubyLLMProvider.new(model: 'gpt-4.1')

    info = provider.model_info

    assert_equal :openai, info[:provider]
  end

  def test_models_constant_has_correct_claude_pricing
    models = OrchestraAI::Providers::RubyLLMProvider::MODELS

    assert_equal 5.00, models['claude-opus-4.5'][:input]
    assert_equal 25.00, models['claude-opus-4.5'][:output]
    assert_equal 3.00, models['claude-sonnet-4.5'][:input]
    assert_equal 15.00, models['claude-sonnet-4.5'][:output]
    assert_equal 1.00, models['claude-haiku-4.5'][:input]
    assert_equal 5.00, models['claude-haiku-4.5'][:output]
  end
end
