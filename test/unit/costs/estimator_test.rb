# frozen_string_literal: true

require 'test_helper'

class EstimatorTest < Minitest::Test
  def setup
    @estimator = OrchestraAI::Costs::Estimator.new
    @task = OrchestraAI::Tasks::Definition.new(
      description: 'Build a simple REST API'
    )
  end

  # Constant tests
  def test_safety_multiplier_constant
    assert_equal 1.3, OrchestraAI::Costs::Estimator::SAFETY_MULTIPLIER
  end

  def test_variance_constants
    assert_equal 0.8, OrchestraAI::Costs::Estimator::VARIANCE_LOW
    assert_equal 1.5, OrchestraAI::Costs::Estimator::VARIANCE_HIGH
  end

  def test_default_token_estimates_constant
    estimates = OrchestraAI::Costs::Estimator::DEFAULT_TOKEN_ESTIMATES

    assert_includes estimates.keys, :architect
    assert_includes estimates.keys, :implementer
    assert_includes estimates.keys, :reviewer
  end

  # Estimate task tests
  def test_estimate_task_returns_hash
    result = @estimator.estimate_task(@task, model: 'gemini-2.5-flash', role: :implementer)

    assert_instance_of Hash, result
  end

  def test_estimate_task_includes_model
    result = @estimator.estimate_task(@task, model: 'gemini-2.5-flash', role: :implementer)

    assert_equal 'gemini-2.5-flash', result[:model]
  end

  def test_estimate_task_includes_role
    result = @estimator.estimate_task(@task, model: 'gemini-2.5-flash', role: :implementer)

    assert_equal :implementer, result[:role]
  end

  def test_estimate_task_includes_provider
    result = @estimator.estimate_task(@task, model: 'gemini-2.5-flash', role: :implementer)

    assert_equal :gemini, result[:provider]
  end

  def test_estimate_task_includes_tokens
    result = @estimator.estimate_task(@task, model: 'gemini-2.5-flash', role: :implementer)

    assert_includes result[:tokens].keys, :input
    assert_includes result[:tokens].keys, :output
    assert result[:tokens][:input].positive?
    assert result[:tokens][:output].positive?
  end

  def test_estimate_task_includes_estimated_cost
    result = @estimator.estimate_task(@task, model: 'gemini-2.5-flash', role: :implementer)

    assert_includes result[:estimated].keys, :input
    assert_includes result[:estimated].keys, :output
    assert_includes result[:estimated].keys, :total
  end

  def test_estimate_task_includes_safe_cost
    result = @estimator.estimate_task(@task, model: 'gemini-2.5-flash', role: :implementer)

    assert_includes result[:safe].keys, :total
    assert result[:safe][:total] > result[:estimated][:total]
  end

  def test_estimate_task_safe_cost_applies_multiplier
    result = @estimator.estimate_task(@task, model: 'gemini-2.5-flash', role: :implementer)

    expected_safe = result[:estimated][:total] * 1.3
    assert_in_delta expected_safe, result[:safe][:total], 0.0001
  end

  def test_estimate_task_includes_confidence_intervals
    result = @estimator.estimate_task(@task, model: 'gemini-2.5-flash', role: :implementer)

    assert_includes result[:confidence].keys, :low
    assert_includes result[:confidence].keys, :high
    assert result[:confidence][:low][:total] < result[:estimated][:total]
    assert result[:confidence][:high][:total] > result[:estimated][:total]
  end

  def test_estimate_task_different_roles_have_different_estimates
    architect_result = @estimator.estimate_task(@task, model: 'gemini-2.5-flash', role: :architect)
    implementer_result = @estimator.estimate_task(@task, model: 'gemini-2.5-flash', role: :implementer)
    reviewer_result = @estimator.estimate_task(@task, model: 'gemini-2.5-flash', role: :reviewer)

    # They should differ based on role token estimates
    refute_equal architect_result[:tokens], implementer_result[:tokens]
    refute_equal implementer_result[:tokens], reviewer_result[:tokens]
  end

  def test_estimate_task_with_unknown_model
    result = @estimator.estimate_task(@task, model: 'unknown-model', role: :implementer)

    assert_equal :unknown, result[:provider]
    assert_equal 0.0, result[:estimated][:total]
  end

  def test_estimate_task_scales_with_description_length
    short_task = OrchestraAI::Tasks::Definition.new(description: 'Fix bug')
    long_task = OrchestraAI::Tasks::Definition.new(description: 'Build a comprehensive REST API with authentication, rate limiting, caching, and extensive documentation' * 5)

    short_result = @estimator.estimate_task(short_task, model: 'gemini-2.5-flash', role: :implementer)
    long_result = @estimator.estimate_task(long_task, model: 'gemini-2.5-flash', role: :implementer)

    assert long_result[:tokens][:input] > short_result[:tokens][:input]
  end

  def test_estimate_task_scales_with_context
    task_no_context = OrchestraAI::Tasks::Definition.new(description: 'Build API')
    task_with_context = OrchestraAI::Tasks::Definition.new(
      description: 'Build API',
      context: ['Previous implementation details...' * 100]
    )

    no_context_result = @estimator.estimate_task(task_no_context, model: 'gemini-2.5-flash', role: :implementer)
    with_context_result = @estimator.estimate_task(task_with_context, model: 'gemini-2.5-flash', role: :implementer)

    assert with_context_result[:tokens][:input] > no_context_result[:tokens][:input]
  end

  # Estimate pipeline tests
  def test_estimate_pipeline_returns_hash
    result = @estimator.estimate_pipeline(
      @task,
      stages: %i[architect implementer reviewer],
      models: %w[gemini-2.5-flash gpt-5-mini claude-haiku-4.5]
    )

    assert_instance_of Hash, result
  end

  def test_estimate_pipeline_includes_stages
    result = @estimator.estimate_pipeline(
      @task,
      stages: %i[architect implementer],
      models: %w[gemini-2.5-flash gpt-5-mini]
    )

    assert_equal 2, result[:stages].length
  end

  def test_estimate_pipeline_aggregates_costs
    result = @estimator.estimate_pipeline(
      @task,
      stages: %i[architect implementer],
      models: %w[gemini-2.5-flash gpt-5-mini]
    )

    stage_total = result[:stages].sum { |s| s[:estimated][:total] }
    assert_in_delta stage_total, result[:estimated][:total], 0.0001
  end

  def test_estimate_pipeline_includes_by_provider
    result = @estimator.estimate_pipeline(
      @task,
      stages: %i[architect implementer],
      models: %w[gemini-2.5-flash gpt-5-mini]
    )

    assert_includes result[:by_provider].keys, :gemini
    assert_includes result[:by_provider].keys, :openai
  end

  def test_estimate_pipeline_uses_last_model_for_extra_stages
    result = @estimator.estimate_pipeline(
      @task,
      stages: %i[architect implementer reviewer],
      models: %w[gemini-2.5-flash gpt-5-mini]
    )

    # Third stage should use gpt-5-mini (last model)
    assert_equal 'gpt-5-mini', result[:stages][2][:model]
  end

  # Estimate with difficulty tests
  def test_estimate_with_difficulty_includes_classification
    result = @estimator.estimate_with_difficulty(@task)

    assert_includes %i[simple moderate complex], result[:classification]
  end

  def test_estimate_with_difficulty_includes_difficulty_score
    result = @estimator.estimate_with_difficulty(@task)

    assert result[:difficulty].is_a?(Float)
    assert result[:difficulty] >= 0.0
    assert result[:difficulty] <= 1.0
  end

  def test_estimate_with_difficulty_includes_stages
    result = @estimator.estimate_with_difficulty(@task)

    assert_instance_of Array, result[:stages]
    refute_empty result[:stages]
  end

  def test_estimate_with_difficulty_includes_models
    result = @estimator.estimate_with_difficulty(@task)

    assert_instance_of Array, result[:models]
    refute_empty result[:models]
  end

  def test_estimate_with_difficulty_simple_task
    simple_task = OrchestraAI::Tasks::Definition.new(description: 'Fix typo')
    result = @estimator.estimate_with_difficulty(simple_task)

    assert_equal :simple, result[:classification]
    assert_equal [:implementer], result[:stages]
  end

  def test_estimate_with_difficulty_complex_task
    complex_task = OrchestraAI::Tasks::Definition.new(
      description: 'Design and implement a distributed microservices architecture with event-driven communication, circuit breakers, rate limiting, and comprehensive security measures including authentication, authorization, encryption, and secure key management'
    )
    result = @estimator.estimate_with_difficulty(complex_task)

    # This should score high enough for complex classification
    assert result[:difficulty] >= 0.5, "Expected difficulty >= 0.5, got #{result[:difficulty]}"
  end

  # Cost for tokens tests
  def test_cost_for_tokens_calculates_correctly
    result = @estimator.cost_for_tokens(
      'claude-opus-4.5',
      input_tokens: 1_000_000,
      output_tokens: 1_000_000
    )

    assert_equal 5.00, result[:input] # $5/1M input
    assert_equal 25.00, result[:output] # $25/1M output
    assert_equal 30.00, result[:total]
  end

  def test_cost_for_tokens_with_small_amounts
    result = @estimator.cost_for_tokens(
      'gemini-2.5-flash',
      input_tokens: 1000,
      output_tokens: 500
    )

    # $0.10/1M input, $0.40/1M output
    assert_in_delta 0.0001, result[:input], 0.00001
    assert_in_delta 0.0002, result[:output], 0.00001
  end

  def test_cost_for_tokens_with_unknown_model
    result = @estimator.cost_for_tokens(
      'unknown-model',
      input_tokens: 1000,
      output_tokens: 500
    )

    assert_nil result
  end

  # Provider for model tests
  def test_provider_for_model_anthropic
    assert_equal :anthropic, @estimator.provider_for_model('claude-opus-4.5')
  end

  def test_provider_for_model_openai
    assert_equal :openai, @estimator.provider_for_model('gpt-5-mini')
  end

  def test_provider_for_model_gemini
    assert_equal :gemini, @estimator.provider_for_model('gemini-2.5-flash')
  end

  def test_provider_for_model_unknown
    assert_equal :unknown, @estimator.provider_for_model('unknown-model')
  end
end
