# frozen_string_literal: true

require 'test_helper'

class ErrorsTest < Minitest::Test
  include OrchestraAITestHelper

  def test_base_error_inherits_from_standard_error
    assert OrchestraAI::Error < StandardError
  end

  def test_configuration_error_inherits_from_error
    assert OrchestraAI::ConfigurationError < OrchestraAI::Error
  end

  def test_missing_api_key_error_inherits_from_configuration_error
    assert OrchestraAI::MissingApiKeyError < OrchestraAI::ConfigurationError
  end

  def test_provider_error_stores_provider_and_original_error
    original = StandardError.new('Original')
    error = OrchestraAI::ProviderError.new('Test error', provider: :anthropic, original_error: original)

    assert_equal 'Test error', error.message
    assert_equal :anthropic, error.provider
    assert_equal original, error.original_error
  end

  def test_provider_not_found_error_inherits_from_provider_error
    assert OrchestraAI::ProviderNotFoundError < OrchestraAI::ProviderError
  end

  def test_provider_authentication_error_inherits_from_provider_error
    assert OrchestraAI::ProviderAuthenticationError < OrchestraAI::ProviderError
  end

  def test_provider_rate_limit_error_inherits_from_provider_error
    assert OrchestraAI::ProviderRateLimitError < OrchestraAI::ProviderError
  end

  def test_provider_timeout_error_inherits_from_provider_error
    assert OrchestraAI::ProviderTimeoutError < OrchestraAI::ProviderError
  end

  def test_task_validation_error_inherits_from_task_error
    assert OrchestraAI::TaskValidationError < OrchestraAI::TaskError
  end

  def test_task_execution_error_inherits_from_task_error
    assert OrchestraAI::TaskExecutionError < OrchestraAI::TaskError
  end

  def test_agent_not_configured_error_inherits_from_agent_error
    assert OrchestraAI::AgentNotConfiguredError < OrchestraAI::AgentError
  end

  def test_pipeline_error_inherits_from_orchestration_error
    assert OrchestraAI::PipelineError < OrchestraAI::OrchestrationError
  end

  def test_parallel_execution_error_stores_failed_and_successful_tasks
    error = OrchestraAI::ParallelExecutionError.new(
      'Parallel failed',
      failed_tasks: [:task1],
      successful_tasks: [:task2, :task3]
    )

    assert_equal 'Parallel failed', error.message
    assert_equal [:task1], error.failed_tasks
    assert_equal [:task2, :task3], error.successful_tasks
  end

  def test_circuit_open_error_stores_provider_and_reset_at
    reset_time = Time.now + 30
    error = OrchestraAI::CircuitOpenError.new(
      'Circuit open',
      provider: :openai,
      reset_at: reset_time
    )

    assert_equal 'Circuit open', error.message
    assert_equal :openai, error.provider
    assert_equal reset_time, error.reset_at
  end
end
