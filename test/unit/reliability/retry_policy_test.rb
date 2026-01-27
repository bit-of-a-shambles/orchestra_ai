# frozen_string_literal: true

require 'test_helper'

class RetryPolicyTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure { |c| c.anthropic_api_key = 'test-key' }
  end

  def test_initialise_with_defaults_from_config
    policy = OrchestraAI::Reliability::RetryPolicy.new

    assert_equal OrchestraAI.configuration.retry_config.max_attempts, policy.max_attempts
    assert_equal OrchestraAI.configuration.retry_config.base_delay, policy.base_delay
    assert_equal OrchestraAI.configuration.retry_config.max_delay, policy.max_delay
  end

  def test_initialise_with_custom_values
    policy = OrchestraAI::Reliability::RetryPolicy.new(
      max_attempts: 5,
      base_delay: 2.0,
      max_delay: 120.0
    )

    assert_equal 5, policy.max_attempts
    assert_equal 2.0, policy.base_delay
    assert_equal 120.0, policy.max_delay
  end

  def test_execute_returns_result_on_success
    policy = OrchestraAI::Reliability::RetryPolicy.new
    attempts = 0

    result = policy.execute do
      attempts += 1
      'success'
    end

    assert_equal 'success', result
    assert_equal 1, attempts
  end

  def test_execute_retries_on_rate_limit_error
    policy = OrchestraAI::Reliability::RetryPolicy.new(max_attempts: 3, base_delay: 0.01)
    attempts = 0

    result = policy.execute do
      attempts += 1
      raise OrchestraAI::ProviderRateLimitError.new('Rate limited', provider: 'test') if attempts < 3

      'success'
    end

    assert_equal 'success', result
    assert_equal 3, attempts
  end

  def test_execute_raises_after_max_attempts
    policy = OrchestraAI::Reliability::RetryPolicy.new(max_attempts: 2, base_delay: 0.01)

    assert_raises(OrchestraAI::ProviderRateLimitError) do
      policy.execute { raise OrchestraAI::ProviderRateLimitError.new('Always fails', provider: 'test') }
    end
  end

  def test_execute_does_not_retry_non_retryable_errors
    policy = OrchestraAI::Reliability::RetryPolicy.new(max_attempts: 3, base_delay: 0.01)
    attempts = 0

    assert_raises(OrchestraAI::ProviderAuthenticationError) do
      policy.execute do
        attempts += 1
        raise OrchestraAI::ProviderAuthenticationError.new('Invalid key', provider: 'test')
      end
    end

    assert_equal 1, attempts
  end

  def test_execute_retries_on_timeout_error
    policy = OrchestraAI::Reliability::RetryPolicy.new(max_attempts: 2, base_delay: 0.01)
    attempts = 0

    result = policy.execute do
      attempts += 1
      raise OrchestraAI::ProviderTimeoutError.new('Timeout', provider: 'test') if attempts < 2

      'done'
    end

    assert_equal 'done', result
    assert_equal 2, attempts
  end

  def test_wrap_returns_retry_wrapper
    policy = OrchestraAI::Reliability::RetryPolicy.new
    mock_provider = Minitest::Mock.new

    wrapped = policy.wrap(mock_provider)

    assert_instance_of OrchestraAI::Reliability::RetryWrapper, wrapped
  end
end

class RetryWrapperTest < Minitest::Test
  include OrchestraAITestHelper

  # Create a test provider class for the wrapper tests
  class TestProvider
    attr_accessor :complete_result, :stream_result, :custom_value

    def initialize
      @complete_result = { content: 'completed' }
      @stream_result = { content: 'streamed' }
      @custom_value = 'test'
    end

    def complete(messages, **options)
      @complete_result
    end

    def stream(messages, **options, &block)
      block&.call('chunk')
      @stream_result
    end

    def custom_method(arg)
      "custom: #{arg}"
    end
  end

  def setup
    super
    OrchestraAI.configure { |c| c.anthropic_api_key = 'test-key' }
    @policy = OrchestraAI::Reliability::RetryPolicy.new(max_attempts: 2, base_delay: 0.01)
    @provider = TestProvider.new
    @wrapper = OrchestraAI::Reliability::RetryWrapper.new(@provider, @policy)
  end

  def test_complete_delegates_through_policy
    result = @wrapper.complete([{ role: 'user', content: 'test' }])

    assert_equal({ content: 'completed' }, result)
  end

  def test_stream_delegates_through_policy
    chunks = []
    result = @wrapper.stream([{ role: 'user', content: 'test' }]) do |chunk|
      chunks << chunk
    end

    assert_equal({ content: 'streamed' }, result)
    assert_includes chunks, 'chunk'
  end

  def test_method_missing_delegates_to_provider
    result = @wrapper.custom_method('arg')

    assert_equal 'custom: arg', result
  end

  def test_respond_to_missing_returns_true_for_provider_methods
    assert @wrapper.respond_to?(:custom_method)
    assert @wrapper.respond_to?(:complete)
    assert @wrapper.respond_to?(:stream)
  end

  def test_respond_to_missing_returns_false_for_unknown_methods
    refute @wrapper.respond_to?(:nonexistent_method)
  end

  def test_raises_no_method_error_for_unknown_methods
    assert_raises(NoMethodError) do
      @wrapper.nonexistent_method
    end
  end
end
