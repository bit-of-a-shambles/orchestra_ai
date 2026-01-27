# frozen_string_literal: true

require 'test_helper'

class BaseProviderTest < Minitest::Test
  include OrchestraAITestHelper

  # Create a test subclass to test Base functionality
  class TestProvider < OrchestraAI::Providers::Base
    def provider_name
      :test
    end

    def default_model
      'test-model'
    end

    def available_models
      ['test-model', 'test-model-2']
    end
  end

  # Minimal subclass that doesn't override abstract methods
  class MinimalProvider < OrchestraAI::Providers::Base
    # Intentionally doesn't override abstract methods
  end

  def setup
    super
    OrchestraAI.configure { |c| c.anthropic_api_key = 'test-key' }
  end

  def test_initialise_stores_api_key
    provider = TestProvider.new(api_key: 'my-api-key')

    assert_equal 'my-api-key', provider.api_key
  end

  def test_initialise_stores_model
    provider = TestProvider.new(api_key: 'key', model: 'custom-model')

    assert_equal 'custom-model', provider.model
  end

  def test_initialise_raises_without_api_key
    assert_raises(OrchestraAI::MissingApiKeyError) do
      TestProvider.new(api_key: nil)
    end
  end

  def test_initialise_raises_with_empty_api_key
    assert_raises(OrchestraAI::MissingApiKeyError) do
      TestProvider.new(api_key: '')
    end
  end

  def test_complete_raises_not_implemented
    provider = TestProvider.new(api_key: 'key')

    assert_raises(NotImplementedError) do
      provider.complete([])
    end
  end

  def test_stream_raises_not_implemented
    provider = TestProvider.new(api_key: 'key')

    assert_raises(NotImplementedError) do
      provider.stream([]) { |_| }
    end
  end

  def test_available_returns_true_with_api_key
    provider = TestProvider.new(api_key: 'valid-key')

    assert provider.available?
  end

  def test_provider_name_returns_symbol
    provider = TestProvider.new(api_key: 'key')

    assert_equal :test, provider.provider_name
  end

  def test_default_model_returns_string
    provider = TestProvider.new(api_key: 'key')

    assert_equal 'test-model', provider.default_model
  end

  def test_available_models_returns_array
    provider = TestProvider.new(api_key: 'key')

    assert_instance_of Array, provider.available_models
    assert_equal 2, provider.available_models.size
  end

  def test_effective_model_uses_provided_model
    provider = TestProvider.new(api_key: 'key', model: 'custom')

    assert_equal 'custom', provider.send(:effective_model)
  end

  def test_effective_model_falls_back_to_default
    provider = TestProvider.new(api_key: 'key')

    assert_equal 'test-model', provider.send(:effective_model)
  end

  def test_normalize_messages_converts_symbols_to_strings
    provider = TestProvider.new(api_key: 'key')
    messages = [{ role: :user, content: 'Hello' }]

    normalized = provider.send(:normalize_messages, messages)

    assert_equal 'user', normalized.first[:role]
    assert_equal 'Hello', normalized.first[:content]
  end

  def test_normalize_messages_handles_string_keys
    provider = TestProvider.new(api_key: 'key')
    messages = [{ 'role' => 'assistant', 'content' => 'Hi' }]

    normalized = provider.send(:normalize_messages, messages)

    assert_equal 'assistant', normalized.first[:role]
    assert_equal 'Hi', normalized.first[:content]
  end

  def test_build_response_creates_response_hash
    provider = TestProvider.new(api_key: 'key')

    response = provider.send(:build_response,
      content: 'Test content',
      model: 'test-model',
      usage: { input_tokens: 10 },
      raw: {}
    )

    assert_equal 'Test content', response[:content]
    assert_equal 'test-model', response[:model]
    assert_equal :test, response[:provider]
    assert response[:timestamp]
  end

  def test_handle_error_wraps_timeout_error
    provider = TestProvider.new(api_key: 'key')
    error = Faraday::TimeoutError.new('timeout')

    assert_raises(OrchestraAI::ProviderTimeoutError) do
      provider.send(:handle_error, error)
    end
  end

  def test_handle_error_wraps_auth_error
    provider = TestProvider.new(api_key: 'key')
    error = Faraday::UnauthorizedError.new('unauthorized')

    assert_raises(OrchestraAI::ProviderAuthenticationError) do
      provider.send(:handle_error, error)
    end
  end

  def test_handle_error_wraps_rate_limit_error
    provider = TestProvider.new(api_key: 'key')
    error = Faraday::TooManyRequestsError.new('rate limited')

    assert_raises(OrchestraAI::ProviderRateLimitError) do
      provider.send(:handle_error, error)
    end
  end

  def test_handle_error_wraps_generic_error
    provider = TestProvider.new(api_key: 'key')
    error = StandardError.new('something went wrong')

    assert_raises(OrchestraAI::ProviderError) do
      provider.send(:handle_error, error)
    end
  end

  def test_provider_name_raises_not_implemented_when_not_overridden
    provider = MinimalProvider.new(api_key: 'key')

    assert_raises(NotImplementedError) do
      provider.provider_name
    end
  end

  def test_default_model_raises_not_implemented_when_not_overridden
    provider = MinimalProvider.new(api_key: 'key')

    assert_raises(NotImplementedError) do
      provider.default_model
    end
  end

  def test_available_models_raises_not_implemented_when_not_overridden
    provider = MinimalProvider.new(api_key: 'key')

    assert_raises(NotImplementedError) do
      provider.available_models
    end
  end
end
