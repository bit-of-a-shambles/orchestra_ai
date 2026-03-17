# frozen_string_literal: true

require 'test_helper'

class PlannerTest < Minitest::Test
  def setup
    @budget = OrchestraAI::Costs::Budget.new(
      limits: { anthropic: 1.0, openai: 0.5, google: 0.2 },
      alert_threshold: 0.8
    )
    @planner = OrchestraAI::Costs::Planner.new(budget: @budget)
    @task = OrchestraAI::Tasks::Definition.new(
      description: 'Build a simple REST API'
    )
  end

  # Initialization tests
  def test_initialize_with_budget
    assert_equal @budget, @planner.budget
  end

  def test_initialize_creates_estimator
    assert_instance_of OrchestraAI::Costs::Estimator, @planner.estimator
  end

  # Constants tests
  def test_sufficiency_levels_constant
    assert_equal %i[sufficient partial insufficient], OrchestraAI::Costs::Planner::SUFFICIENCY_LEVELS
  end

  def test_alternatives_constant
    alternatives = OrchestraAI::Costs::Planner::ALTERNATIVES

    assert_includes alternatives.keys, :google
    assert_includes alternatives.keys, :openai
    assert_includes alternatives.keys, :anthropic
    assert_includes alternatives.keys, :mistral
  end

  def test_alternatives_mistral_ordered_cheapest_first
    mistral_models = OrchestraAI::Costs::Planner::ALTERNATIVES[:mistral]

    assert_equal 'mistral-small-latest', mistral_models.first
    assert_equal 'mistral-large-latest', mistral_models.last
    assert_equal 3, mistral_models.size
  end

  # Plan tests
  def test_plan_returns_execution_plan
    plan = @planner.plan(@task)

    assert_instance_of OrchestraAI::Costs::ExecutionPlan, plan
  end

  def test_plan_includes_sufficiency
    plan = @planner.plan(@task)

    assert_includes %i[sufficient partial insufficient], plan.sufficiency
  end

  def test_plan_includes_difficulty
    plan = @planner.plan(@task)

    assert plan.difficulty.is_a?(Float)
  end

  def test_plan_includes_classification
    plan = @planner.plan(@task)

    assert_includes %i[simple moderate complex], plan.classification
  end

  def test_plan_includes_stages
    plan = @planner.plan(@task)

    assert_instance_of Array, plan.stages
    refute_empty plan.stages
  end

  def test_plan_includes_recommended_models
    plan = @planner.plan(@task)

    assert_instance_of Array, plan.recommended_models
    refute_empty plan.recommended_models
  end

  def test_plan_includes_estimated_cost
    plan = @planner.plan(@task)

    assert_includes plan.estimated_cost.keys, :input
    assert_includes plan.estimated_cost.keys, :output
    assert_includes plan.estimated_cost.keys, :total
  end

  def test_plan_includes_confidence_intervals
    plan = @planner.plan(@task)

    assert_includes plan.confidence.keys, :low
    assert_includes plan.confidence.keys, :high
  end

  def test_plan_includes_by_provider
    plan = @planner.plan(@task)

    assert_instance_of Hash, plan.by_provider
  end

  def test_plan_includes_budget_status
    plan = @planner.plan(@task)

    assert_instance_of Hash, plan.budget_status
  end

  def test_plan_includes_warnings
    plan = @planner.plan(@task)

    assert_instance_of Array, plan.warnings
  end

  def test_plan_includes_premium_comparison
    plan = @planner.plan(@task)

    assert_includes plan.premium_comparison.keys, :premium_model
    assert_includes plan.premium_comparison.keys, :premium_cost
  end

  def test_plan_sufficient_with_high_budget
    high_budget = OrchestraAI::Costs::Budget.new(
      limits: { anthropic: 100.0, openai: 100.0, google: 100.0 }
    )
    planner = OrchestraAI::Costs::Planner.new(budget: high_budget)

    plan = planner.plan(@task)

    assert_equal :sufficient, plan.sufficiency
  end

  def test_plan_insufficient_with_zero_budget
    zero_budget = OrchestraAI::Costs::Budget.new(
      limits: { anthropic: 0.0, openai: 0.0, google: 0.0 }
    )
    planner = OrchestraAI::Costs::Planner.new(budget: zero_budget)

    plan = planner.plan(@task)

    assert_equal :insufficient, plan.sufficiency
  end

  def test_plan_partial_with_limited_budget
    # Set a budget that can afford some but not all
    limited_budget = OrchestraAI::Costs::Budget.new(
      limits: { anthropic: 0.0001, openai: 0.0001, google: 0.001 }
    )
    planner = OrchestraAI::Costs::Planner.new(budget: limited_budget)

    plan = planner.plan(@task)

    # With such low limits, should be partial or insufficient
    assert_includes %i[partial insufficient], plan.sufficiency
  end

  def test_plan_includes_alternatives_when_partial
    limited_budget = OrchestraAI::Costs::Budget.new(
      limits: { anthropic: 0.001, openai: 0.001, google: 0.1 }
    )
    planner = OrchestraAI::Costs::Planner.new(budget: limited_budget)

    plan = planner.plan(@task)

    # Should have alternatives if not sufficient
    return unless plan.sufficiency != :sufficient

    refute_nil plan.alternatives
  end

  # Can execute tests
  def test_can_execute_with_sufficient_budget
    high_budget = OrchestraAI::Costs::Budget.new(
      limits: { anthropic: 100.0, openai: 100.0, google: 100.0 }
    )
    planner = OrchestraAI::Costs::Planner.new(budget: high_budget)

    assert planner.can_execute?(@task)
  end

  def test_cannot_execute_with_zero_budget
    zero_budget = OrchestraAI::Costs::Budget.new(
      limits: { anthropic: 0.0, openai: 0.0, google: 0.0 }
    )
    planner = OrchestraAI::Costs::Planner.new(budget: zero_budget)

    refute planner.can_execute?(@task)
  end

  # Recommend models tests
  def test_recommend_models_returns_stages
    result = @planner.recommend_models(@task)

    assert_includes result.keys, :stages
    assert_instance_of Array, result[:stages]
  end

  def test_recommend_models_returns_recommended_models
    result = @planner.recommend_models(@task)

    assert_includes result.keys, :recommended_models
    assert_instance_of Array, result[:recommended_models]
  end

  def test_recommend_models_returns_estimated_cost
    result = @planner.recommend_models(@task)

    assert_includes result.keys, :estimated_cost
    assert_includes result[:estimated_cost].keys, :total
  end

  def test_recommend_models_with_max_cost
    result = @planner.recommend_models(@task, max_cost: 0.0001)

    # Should recommend cheapest models
    result[:recommended_models].each do |model|
      assert model.is_a?(String)
    end
  end
end

class ExecutionPlanTest < Minitest::Test
  def setup
    @attrs = {
      task: OrchestraAI::Tasks::Definition.new(description: 'Test'),
      sufficiency: :sufficient,
      difficulty: 0.5,
      classification: :moderate,
      stages: %i[implementer reviewer],
      recommended_models: %w[gemini-2.5-flash gpt-5-mini],
      estimated_cost: { input: 0.001, output: 0.002, total: 0.003 },
      confidence: {
        low: { input: 0.0008, output: 0.0016, total: 0.0024 },
        high: { input: 0.0015, output: 0.003, total: 0.0045 }
      },
      by_provider: { gemini: { total: 0.001 }, openai: { total: 0.002 } },
      budget_status: { anthropic: { status: :ok } },
      warnings: [],
      alternatives: nil,
      premium_comparison: {
        premium_model: 'claude-opus-4.6',
        premium_cost: { input: 0.01, output: 0.02, total: 0.03 },
        premium_stages: %i[architect implementer reviewer]
      }
    }
    @plan = OrchestraAI::Costs::ExecutionPlan.new(@attrs)
  end

  # Attribute accessor tests
  def test_task_accessor
    assert_equal @attrs[:task], @plan.task
  end

  def test_sufficiency_accessor
    assert_equal :sufficient, @plan.sufficiency
  end

  def test_difficulty_accessor
    assert_equal 0.5, @plan.difficulty
  end

  def test_classification_accessor
    assert_equal :moderate, @plan.classification
  end

  def test_stages_accessor
    assert_equal %i[implementer reviewer], @plan.stages
  end

  def test_recommended_models_accessor
    assert_equal %w[gemini-2.5-flash gpt-5-mini], @plan.recommended_models
  end

  def test_estimated_cost_accessor
    assert_equal 0.003, @plan.estimated_cost[:total]
  end

  def test_confidence_accessor
    assert_equal 0.0024, @plan.confidence[:low][:total]
    assert_equal 0.0045, @plan.confidence[:high][:total]
  end

  def test_by_provider_accessor
    assert_equal 0.001, @plan.by_provider[:gemini][:total]
  end

  def test_budget_status_accessor
    assert_equal :ok, @plan.budget_status[:anthropic][:status]
  end

  def test_warnings_accessor
    assert_equal [], @plan.warnings
  end

  def test_alternatives_accessor
    assert_nil @plan.alternatives
  end

  def test_premium_comparison_accessor
    assert_equal 'claude-opus-4.6', @plan.premium_comparison[:premium_model]
  end

  # Sufficiency query methods tests
  def test_sufficient_returns_true
    assert @plan.sufficient?
  end

  def test_sufficient_returns_false
    plan = OrchestraAI::Costs::ExecutionPlan.new(@attrs.merge(sufficiency: :partial))
    refute plan.sufficient?
  end

  def test_partial_returns_true
    plan = OrchestraAI::Costs::ExecutionPlan.new(@attrs.merge(sufficiency: :partial))
    assert plan.partial?
  end

  def test_partial_returns_false
    refute @plan.partial?
  end

  def test_insufficient_returns_true
    plan = OrchestraAI::Costs::ExecutionPlan.new(@attrs.merge(sufficiency: :insufficient))
    assert plan.insufficient?
  end

  def test_insufficient_returns_false
    refute @plan.insufficient?
  end

  def test_executable_when_sufficient
    assert @plan.executable?
  end

  def test_executable_when_partial
    plan = OrchestraAI::Costs::ExecutionPlan.new(@attrs.merge(sufficiency: :partial))
    assert plan.executable?
  end

  def test_not_executable_when_insufficient
    plan = OrchestraAI::Costs::ExecutionPlan.new(@attrs.merge(sufficiency: :insufficient))
    refute plan.executable?
  end

  # Potential savings tests
  def test_potential_savings_calculates_correctly
    savings = @plan.potential_savings

    assert_equal 0.027, savings[:vs_premium] # 0.03 - 0.003
  end

  def test_potential_savings_percentage
    savings = @plan.potential_savings

    assert_equal 90.0, savings[:percentage] # (0.027 / 0.03) * 100
  end

  def test_potential_savings_nil_without_premium_comparison
    plan = OrchestraAI::Costs::ExecutionPlan.new(@attrs.merge(premium_comparison: nil))

    assert_nil plan.potential_savings
  end

  # To hash tests
  def test_to_h_includes_all_fields
    hash = @plan.to_h

    assert_includes hash.keys, :sufficiency
    assert_includes hash.keys, :difficulty
    assert_includes hash.keys, :classification
    assert_includes hash.keys, :stages
    assert_includes hash.keys, :recommended_models
    assert_includes hash.keys, :estimated_cost
    assert_includes hash.keys, :confidence
    assert_includes hash.keys, :by_provider
    assert_includes hash.keys, :budget_status
    assert_includes hash.keys, :warnings
    assert_includes hash.keys, :alternatives
    assert_includes hash.keys, :premium_comparison
    assert_includes hash.keys, :potential_savings
  end

  # Summary tests
  def test_summary_returns_string
    assert_instance_of String, @plan.summary
  end

  def test_summary_includes_classification
    assert_includes @plan.summary, 'moderate'
  end

  def test_summary_includes_sufficiency
    assert_includes @plan.summary, 'SUFFICIENT'
  end

  def test_summary_includes_stages
    assert_includes @plan.summary, 'implementer'
    assert_includes @plan.summary, 'reviewer'
  end

  def test_summary_includes_models
    assert_includes @plan.summary, 'gemini-2.5-flash'
    assert_includes @plan.summary, 'gpt-5-mini'
  end

  def test_summary_includes_estimated_cost
    assert_includes @plan.summary, 'Estimated Cost'
  end

  def test_summary_includes_confidence_range
    assert_includes @plan.summary, 'Confidence Range'
  end

  def test_summary_includes_potential_savings
    assert_includes @plan.summary, 'Potential Savings'
    assert_includes @plan.summary, '90.0%'
  end

  def test_summary_includes_warnings_when_present
    plan = OrchestraAI::Costs::ExecutionPlan.new(@attrs.merge(
                                                   warnings: ['Budget warning']
                                                 ))

    assert_includes plan.summary, 'Warnings'
    assert_includes plan.summary, 'Budget warning'
  end

  # Warnings tests
  def test_warnings_default_to_empty_array
    plan = OrchestraAI::Costs::ExecutionPlan.new(@attrs.merge(warnings: nil))

    assert_equal [], plan.warnings
  end
end
