# frozen_string_literal: true

require 'test_helper'

class ConductorTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure do |c|
      c.anthropic_api_key = 'test-key'
      c.openai_api_key = 'test-key'
      c.google_api_key = 'test-key'
    end
    @conductor = OrchestraAI::Orchestration::Conductor.new
    @mock_provider = OrchestraAI::Testing::MockProvider.new(responses: ['Mock response'])
  end

  def test_pipeline_returns_pipeline_pattern
    pipeline = @conductor.pipeline

    assert_instance_of OrchestraAI::Orchestration::Patterns::Pipeline, pipeline
  end

  def test_pipeline_accepts_block_for_configuration
    pipeline = @conductor.pipeline do |p|
      p.stage(:test) { |t, _ctx| 'result' }
    end

    assert_equal 1, pipeline.stages.size
    assert_equal :test, pipeline.stages.first[:name]
  end

  def test_parallel_returns_parallel_pattern
    task1 = OrchestraAI::Tasks::Definition.new(description: 'Task 1')
    task2 = OrchestraAI::Tasks::Definition.new(description: 'Task 2')

    parallel = @conductor.parallel(task1, task2)

    assert_instance_of OrchestraAI::Orchestration::Patterns::Parallel, parallel
    assert_equal 2, parallel.tasks.size
  end

  def test_sequential_returns_sequential_pattern
    task1 = OrchestraAI::Tasks::Definition.new(description: 'Task 1')
    task2 = OrchestraAI::Tasks::Definition.new(description: 'Task 2')

    sequential = @conductor.sequential(task1, task2)

    assert_instance_of OrchestraAI::Orchestration::Patterns::Sequential, sequential
    assert_equal 2, sequential.tasks.size
  end

  def test_router_returns_router_pattern
    router = @conductor.router

    assert_instance_of OrchestraAI::Orchestration::Patterns::Router, router
  end

  def test_router_accepts_block_for_configuration
    router = @conductor.router do |r|
      r.default { |t| 'default result' }
    end

    refute_nil router.default_route
  end

  def test_execute_raises_for_unknown_pattern
    task = OrchestraAI::Tasks::Definition.new(description: 'Test')

    assert_raises(ArgumentError) do
      @conductor.execute(task, pattern: :unknown)
    end
  end

  def test_execute_with_parallel_pattern_for_single_task_falls_back_to_auto
    # Single task with parallel pattern should fall back to auto (not raise error)
    task = OrchestraAI::Tasks::Definition.new(description: 'Test task', difficulty: 0.1)

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      result = @conductor.execute(task, pattern: :parallel)

      # Should execute successfully using auto pattern
      assert result.success?
    end
  end

  def test_execute_with_sequential_pattern_for_single_task_falls_back_to_auto
    # Single task with sequential pattern should fall back to auto
    task = OrchestraAI::Tasks::Definition.new(description: 'Test task', difficulty: 0.1)

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      result = @conductor.execute(task, pattern: :sequential)

      # Should execute successfully using auto pattern
      assert result.success?
    end
  end

  def test_execute_with_auto_pattern_for_simple_task
    task = OrchestraAI::Tasks::Definition.new(description: 'fix typo', difficulty: 0.1)

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      result = @conductor.execute(task, pattern: :auto)

      assert result.success?
    end
  end

  def test_execute_with_auto_pattern_for_moderate_task
    @mock_provider = OrchestraAI::Testing::MockProvider.new(responses: %w[Implementation Review])
    task = OrchestraAI::Tasks::Definition.new(
      description: 'Add a new feature',
      difficulty: 0.5
    )

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      result = @conductor.execute(task, pattern: :auto)

      # Moderate tasks go through implement -> review
      assert result.success?
      assert_equal 2, @mock_provider.calls.size
    end
  end

  def test_execute_with_auto_pattern_for_moderate_task_stops_on_failure
    error_then_success = OrchestraAI::Testing::MockProvider.new(responses: [])
    error_then_success.queue_error(StandardError.new('Implementation failed'))

    task = OrchestraAI::Tasks::Definition.new(
      description: 'Add a new feature',
      difficulty: 0.5
    )

    OrchestraAI::Providers::Registry.stub(:create_for_model, error_then_success) do
      result = @conductor.execute(task, pattern: :auto)

      # Should return a failed result
      assert result.failed?
    end
  end

  def test_execute_with_auto_pattern_for_complex_task
    @mock_provider = OrchestraAI::Testing::MockProvider.new(responses: %w[Plan Implementation Review])
    task = OrchestraAI::Tasks::Definition.new(
      description: 'Design and implement a distributed system',
      difficulty: 0.9
    )

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      result = @conductor.execute(task, pattern: :auto)

      # Complex tasks go through architect -> implement -> review
      # PipelineResult is returned
      assert result.respond_to?(:completed_stages)
      assert_equal 3, @mock_provider.calls.size
    end
  end

  def test_execute_with_pipeline_pattern
    @mock_provider = OrchestraAI::Testing::MockProvider.new(responses: %w[Plan Implementation Review])
    task = OrchestraAI::Tasks::Definition.new(description: 'Build something')

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      result = @conductor.execute(task, pattern: :pipeline)

      # PipelineResult is returned
      assert result.respond_to?(:completed_stages)
    end
  end

  def test_execute_default_pattern_is_auto
    task = OrchestraAI::Tasks::Definition.new(description: 'fix typo', difficulty: 0.1)

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      result = @conductor.execute(task)

      # Default should be :auto, which for simple tasks uses implementer
      assert result.success?
    end
  end
end
