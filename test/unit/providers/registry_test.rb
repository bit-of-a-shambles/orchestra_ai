# frozen_string_literal: true

require 'test_helper'

class RegistryTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure do |c|
      c.anthropic_api_key = 'test-key'
      c.openai_api_key = 'test-key'
      c.google_api_key = 'test-key'
    end
  end

  # All providers now use the unified RubyLLMProvider
  def test_get_returns_ruby_llm_provider_for_anthropic
    provider_class = OrchestraAI::Providers::Registry.get(:anthropic)

    assert_equal OrchestraAI::Providers::RubyLLMProvider, provider_class
  end

  def test_get_returns_ruby_llm_provider_for_openai
    provider_class = OrchestraAI::Providers::Registry.get(:openai)

    assert_equal OrchestraAI::Providers::RubyLLMProvider, provider_class
  end

  def test_get_returns_ruby_llm_provider_for_google
    provider_class = OrchestraAI::Providers::Registry.get(:google)

    assert_equal OrchestraAI::Providers::RubyLLMProvider, provider_class
  end

  def test_for_model_returns_ruby_llm_provider_for_claude
    provider_class = OrchestraAI::Providers::Registry.for_model('claude-opus-4.5')

    assert_equal OrchestraAI::Providers::RubyLLMProvider, provider_class
  end

  def test_for_model_returns_ruby_llm_provider_for_gpt
    provider_class = OrchestraAI::Providers::Registry.for_model('gpt-4.1')

    assert_equal OrchestraAI::Providers::RubyLLMProvider, provider_class
  end

  def test_for_model_returns_ruby_llm_provider_for_gemini
    provider_class = OrchestraAI::Providers::Registry.for_model('gemini-2.5-flash')

    assert_equal OrchestraAI::Providers::RubyLLMProvider, provider_class
  end

  def test_for_model_raises_for_unknown_model
    assert_raises(OrchestraAI::ProviderNotFoundError) do
      OrchestraAI::Providers::Registry.for_model('unknown-model')
    end
  end

  def test_create_method_exists
    assert_respond_to OrchestraAI::Providers::Registry, :create
  end

  def test_create_returns_ruby_llm_provider_instance
    provider = OrchestraAI::Providers::Registry.create(:anthropic)

    assert_instance_of OrchestraAI::Providers::RubyLLMProvider, provider
  end

  def test_create_accepts_options
    provider = OrchestraAI::Providers::Registry.create(:openai, model: 'gpt-4.1')

    assert_instance_of OrchestraAI::Providers::RubyLLMProvider, provider
  end

  def test_create_for_model_method_exists
    assert_respond_to OrchestraAI::Providers::Registry, :create_for_model
  end

  def test_create_for_model_returns_provider_instance
    provider = OrchestraAI::Providers::Registry.create_for_model('gemini-2.5-flash')

    assert_instance_of OrchestraAI::Providers::RubyLLMProvider, provider
  end

  def test_create_for_model_raises_for_unknown_model
    assert_raises(OrchestraAI::ProviderNotFoundError) do
      OrchestraAI::Providers::Registry.create_for_model('unknown-model')
    end
  end

  def test_all_models_returns_array_of_model_names
    models = OrchestraAI::Providers::Registry.all_models

    assert_instance_of Array, models
    assert_includes models, 'claude-opus-4.5'
    assert_includes models, 'gpt-4.1'
    assert_includes models, 'gemini-2.5-flash'
    assert_includes models, 'gpt-5.2-codex'
  end

  def test_models_for_provider_returns_provider_specific_models
    anthropic_models = OrchestraAI::Providers::Registry.models_for_provider(:anthropic)

    assert anthropic_models.all? { |m| m.include?('claude') }
  end

  def test_provider_for_model_returns_provider_symbol
    provider = OrchestraAI::Providers::Registry.provider_for_model('gpt-4.1')

    assert_equal :openai, provider
  end

  def test_model_available_returns_true_for_configured_provider
    available = OrchestraAI::Providers::Registry.model_available?('claude-opus-4.5')

    assert available
  end

  def test_model_available_returns_false_for_unknown_model
    available = OrchestraAI::Providers::Registry.model_available?('nonexistent-model')

    refute available
  end

  def test_available_providers_returns_configured_providers
    providers = OrchestraAI::Providers::Registry.available_providers

    assert_includes providers, :anthropic
    assert_includes providers, :openai
    assert_includes providers, :google
  end
end
