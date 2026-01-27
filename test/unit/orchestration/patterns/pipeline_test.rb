# frozen_string_literal: true

require 'test_helper'

class PipelinePatternTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure do |c|
      c.anthropic_api_key = 'test-key'
      c.openai_api_key = 'test-key'
      c.google_api_key = 'test-key'
    end
    @pipeline = OrchestraAI::Orchestration::Patterns::Pipeline.new
  end

  def test_initialise_with_empty_stages
    assert_empty @pipeline.stages
    assert_empty @pipeline.results
  end

  def test_stage_adds_stage_to_pipeline
    @pipeline.stage(:first) { |t, ctx| 'result' }

    assert_equal 1, @pipeline.stages.size
    assert_equal :first, @pipeline.stages.first[:name]
  end

  def test_stage_returns_self_for_chaining
    result = @pipeline.stage(:test) { |t, ctx| 'result' }

    assert_same @pipeline, result
  end

  def test_multiple_stages_can_be_added
    @pipeline
      .stage(:plan) { |t, ctx| 'plan' }
      .stage(:implement) { |t, ctx| 'code' }
      .stage(:review) { |t, ctx| 'review' }

    assert_equal 3, @pipeline.stages.size
    assert_equal [:plan, :implement, :review], @pipeline.stages.map { |s| s[:name] }
  end

  def test_standard_creates_three_stage_pipeline
    pipeline = OrchestraAI::Orchestration::Patterns::Pipeline.standard

    assert_equal 3, pipeline.stages.size
    assert_equal :plan, pipeline.stages[0][:name]
    assert_equal :implement, pipeline.stages[1][:name]
    assert_equal :review, pipeline.stages[2][:name]
  end
end

class PipelineResultTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure { |c| c.anthropic_api_key = 'test-key' }
    @task = OrchestraAI::Tasks::Definition.new(description: 'Test')
  end

  def test_success_when_all_stages_complete
    result = OrchestraAI::Orchestration::Patterns::PipelineResult.new(
      results: { plan: 'done', implement: 'done' },
      completed_stages: [:plan, :implement],
      failed_stage: nil,
      success: true
    )

    assert result.success?
    refute result.failed?
  end

  def test_failed_when_stage_fails
    result = OrchestraAI::Orchestration::Patterns::PipelineResult.new(
      results: { plan: 'done' },
      completed_stages: [:plan],
      failed_stage: :implement,
      success: false
    )

    refute result.success?
    assert result.failed?
    assert_equal :implement, result.failed_stage
  end

  def test_results_contains_stage_outputs
    result = OrchestraAI::Orchestration::Patterns::PipelineResult.new(
      results: { plan: 'architecture', implement: 'code' },
      completed_stages: [:plan, :implement],
      failed_stage: nil,
      success: true
    )

    assert_equal 'architecture', result.results[:plan]
    assert_equal 'code', result.results[:implement]
  end

  def test_completed_stages_lists_finished_stages
    result = OrchestraAI::Orchestration::Patterns::PipelineResult.new(
      results: { plan: 'done', implement: 'done', review: 'done' },
      completed_stages: [:plan, :implement, :review],
      failed_stage: nil,
      success: true
    )

    assert_equal [:plan, :implement, :review], result.completed_stages
  end

  def test_bracket_accessor_returns_stage_result
    plan_result = OrchestraAI::Tasks::Result.new(content: 'Plan output', task: @task, agent: :architect)
    result = OrchestraAI::Orchestration::Patterns::PipelineResult.new(
      results: { plan: plan_result },
      completed_stages: [:plan],
      failed_stage: nil,
      success: true
    )

    assert_same plan_result, result[:plan]
  end

  def test_final_returns_last_stage_result
    final_result = OrchestraAI::Tasks::Result.new(content: 'Final', task: @task, agent: :reviewer)
    result = OrchestraAI::Orchestration::Patterns::PipelineResult.new(
      results: {
        plan: OrchestraAI::Tasks::Result.new(content: 'Plan', task: @task, agent: :architect),
        review: final_result
      },
      completed_stages: [:plan, :review],
      failed_stage: nil,
      success: true
    )

    assert_same final_result, result.final
  end

  def test_final_returns_nil_for_empty_results
    result = OrchestraAI::Orchestration::Patterns::PipelineResult.new(
      results: {},
      completed_stages: [],
      failed_stage: :plan,
      success: false
    )

    assert_nil result.final
  end

  def test_content_formats_all_stages
    result = OrchestraAI::Orchestration::Patterns::PipelineResult.new(
      results: {
        plan: OrchestraAI::Tasks::Result.new(content: 'Architecture', task: @task, agent: :architect),
        implement: OrchestraAI::Tasks::Result.new(content: 'Code', task: @task, agent: :implementer)
      },
      completed_stages: [:plan, :implement],
      failed_stage: nil,
      success: true
    )

    content = result.content

    assert_includes content, 'Plan'
    assert_includes content, 'Architecture'
    assert_includes content, 'Implement'
    assert_includes content, 'Code'
  end

  def test_total_cost_returns_nil_without_costs
    result = OrchestraAI::Orchestration::Patterns::PipelineResult.new(
      results: {
        plan: OrchestraAI::Tasks::Result.new(content: 'Plan', task: @task, agent: :architect)
      },
      completed_stages: [:plan],
      failed_stage: nil,
      success: true
    )

    assert_nil result.total_cost
  end

  def test_total_cost_sums_all_stage_costs
    results = {
      plan: OrchestraAI::Tasks::Result.new(
        content: 'Plan',
        task: @task,
        agent: :architect,
        model: 'gpt-5-mini',
        usage: { input_tokens: 100, output_tokens: 50 }
      ),
      implement: OrchestraAI::Tasks::Result.new(
        content: 'Code',
        task: @task,
        agent: :implementer,
        model: 'gpt-5-mini',
        usage: { input_tokens: 200, output_tokens: 100 }
      )
    }
    result = OrchestraAI::Orchestration::Patterns::PipelineResult.new(
      results: results,
      completed_stages: [:plan, :implement],
      failed_stage: nil,
      success: true
    )

    cost = result.total_cost
    refute_nil cost
    assert cost[:input] > 0
    assert cost[:output] > 0
    assert cost[:total] > 0
  end

  def test_stage_costs_returns_cost_per_stage
    results = {
      plan: OrchestraAI::Tasks::Result.new(
        content: 'Plan',
        task: @task,
        agent: :architect,
        model: 'gpt-5-mini',
        usage: { input_tokens: 100, output_tokens: 50 }
      )
    }
    result = OrchestraAI::Orchestration::Patterns::PipelineResult.new(
      results: results,
      completed_stages: [:plan],
      failed_stage: nil,
      success: true
    )

    costs = result.stage_costs

    assert costs.key?(:plan)
  end
end

class PipelineExecutionTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure do |c|
      c.anthropic_api_key = 'test-key'
      c.openai_api_key = 'test-key'
      c.google_api_key = 'test-key'
    end
    @mock_provider = OrchestraAI::Testing::MockProvider.new(responses: ['Response 1', 'Response 2', 'Response 3'])
    @task = OrchestraAI::Tasks::Definition.new(description: 'Test task')
  end

  def test_execute_runs_stages_in_order
    pipeline = OrchestraAI::Orchestration::Patterns::Pipeline.new
    execution_order = []

    pipeline.stage(:first) do |task, ctx|
      execution_order << :first
      OrchestraAI::Tasks::Result.new(content: 'First', task: task, agent: :architect)
    end

    pipeline.stage(:second) do |task, ctx|
      execution_order << :second
      OrchestraAI::Tasks::Result.new(content: 'Second', task: task, agent: :implementer)
    end

    result = pipeline.execute(@task)

    assert_equal [:first, :second], execution_order
    assert result.success?
  end

  def test_execute_stops_on_failed_stage
    pipeline = OrchestraAI::Orchestration::Patterns::Pipeline.new
    execution_order = []

    pipeline.stage(:first) do |task, ctx|
      execution_order << :first
      OrchestraAI::Tasks::Result.new(
        content: nil,
        task: task,
        agent: :architect,
        error: StandardError.new('Failed'),
        success: false
      )
    end

    pipeline.stage(:second) do |task, ctx|
      execution_order << :second
      OrchestraAI::Tasks::Result.new(content: 'Should not run', task: task, agent: :implementer)
    end

    result = pipeline.execute(@task)

    assert_equal [:first], execution_order
    refute result.success?
    assert_equal :first, result.failed_stage
  end

  def test_execute_passes_context_between_stages
    pipeline = OrchestraAI::Orchestration::Patterns::Pipeline.new

    pipeline.stage(:first) do |task, ctx|
      OrchestraAI::Tasks::Result.new(content: 'First result', task: task, agent: :architect)
    end

    pipeline.stage(:second) do |task, ctx|
      # ctx[:first] should contain the result from first stage
      received_context = ctx[:first]&.content
      OrchestraAI::Tasks::Result.new(content: "Got: #{received_context}", task: task, agent: :implementer)
    end

    result = pipeline.execute(@task)

    assert result.success?
    assert_includes result[:second].content, 'First result'
  end

  def test_standard_pipeline_executes_correctly
    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      pipeline = OrchestraAI::Orchestration::Patterns::Pipeline.standard
      result = pipeline.execute(@task)

      assert_instance_of OrchestraAI::Orchestration::Patterns::PipelineResult, result
      # Should have run 3 stages
      assert_equal 3, @mock_provider.calls.size
    end
  end
end
