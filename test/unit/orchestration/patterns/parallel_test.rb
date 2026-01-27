# frozen_string_literal: true

require 'test_helper'

class ParallelPatternTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure do |c|
      c.anthropic_api_key = 'test-key'
      c.openai_api_key = 'test-key'
      c.google_api_key = 'test-key'
    end
  end

  def test_initialise_with_single_task
    task = OrchestraAI::Tasks::Definition.new(description: 'Single task')
    pattern = OrchestraAI::Orchestration::Patterns::Parallel.new(task)

    assert_equal 1, pattern.tasks.size
  end

  def test_initialise_with_multiple_tasks
    tasks = [
      OrchestraAI::Tasks::Definition.new(description: 'Task 1'),
      OrchestraAI::Tasks::Definition.new(description: 'Task 2'),
      OrchestraAI::Tasks::Definition.new(description: 'Task 3')
    ]
    pattern = OrchestraAI::Orchestration::Patterns::Parallel.new(tasks)

    assert_equal 3, pattern.tasks.size
  end

  def test_initialise_with_agent_option
    task = OrchestraAI::Tasks::Definition.new(description: 'Task')
    pattern = OrchestraAI::Orchestration::Patterns::Parallel.new(task, agent: :implementer)

    assert_equal :implementer, pattern.agent
  end

  def test_initialise_with_max_threads_option
    task = OrchestraAI::Tasks::Definition.new(description: 'Task')
    pattern = OrchestraAI::Orchestration::Patterns::Parallel.new(task, max_threads: 4)

    assert_equal 4, pattern.instance_variable_get(:@max_threads)
  end

  def test_initialise_with_timeout_option
    task = OrchestraAI::Tasks::Definition.new(description: 'Task')
    pattern = OrchestraAI::Orchestration::Patterns::Parallel.new(task, timeout: 60)

    assert_equal 60, pattern.instance_variable_get(:@timeout)
  end

  def test_results_starts_empty
    task = OrchestraAI::Tasks::Definition.new(description: 'Task')
    pattern = OrchestraAI::Orchestration::Patterns::Parallel.new(task)

    assert_empty pattern.results
  end
end

class ParallelResultTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure { |c| c.anthropic_api_key = 'test-key' }
    @task = OrchestraAI::Tasks::Definition.new(description: 'Test')
  end

  def test_success_when_all_results_succeed
    results = [
      OrchestraAI::Tasks::Result.new(content: 'A', task: @task, agent: :architect),
      OrchestraAI::Tasks::Result.new(content: 'B', task: @task, agent: :implementer)
    ]
    par_result = OrchestraAI::Orchestration::Patterns::ParallelResult.new(results)

    assert par_result.success?
  end

  def test_partial_success_when_some_succeed
    results = [
      OrchestraAI::Tasks::Result.new(content: 'A', task: @task, agent: :architect),
      OrchestraAI::Tasks::Result.new(content: nil, task: @task, agent: :implementer, error: StandardError.new,
                                     success: false)
    ]
    par_result = OrchestraAI::Orchestration::Patterns::ParallelResult.new(results)

    # Has at least one success and one failure
    assert par_result.successful.size > 0
    assert par_result.failures.size > 0
  end

  def test_successful_returns_only_successful_results
    good = OrchestraAI::Tasks::Result.new(content: 'A', task: @task, agent: :architect)
    bad = OrchestraAI::Tasks::Result.new(content: nil, task: @task, agent: :implementer, error: StandardError.new,
                                         success: false)
    par_result = OrchestraAI::Orchestration::Patterns::ParallelResult.new([good, bad])

    successful = par_result.successful
    assert_equal 1, successful.size
    assert_same good, successful.first
  end

  def test_failures_returns_only_failed_results
    good = OrchestraAI::Tasks::Result.new(content: 'A', task: @task, agent: :architect)
    bad = OrchestraAI::Tasks::Result.new(content: nil, task: @task, agent: :implementer, error: StandardError.new,
                                         success: false)
    par_result = OrchestraAI::Orchestration::Patterns::ParallelResult.new([good, bad])

    failures = par_result.failures
    assert_equal 1, failures.size
    assert_same bad, failures.first
  end

  def test_success_rate_calculates_ratio
    results = [
      OrchestraAI::Tasks::Result.new(content: 'A', task: @task, agent: :architect),
      OrchestraAI::Tasks::Result.new(content: 'B', task: @task, agent: :implementer),
      OrchestraAI::Tasks::Result.new(content: nil, task: @task, agent: :reviewer, error: StandardError.new,
                                     success: false)
    ]
    par_result = OrchestraAI::Orchestration::Patterns::ParallelResult.new(results)

    # 2 out of 3 successful
    assert_in_delta 0.666, par_result.success_rate, 0.01
  end

  def test_to_a_returns_results_array
    results = [
      OrchestraAI::Tasks::Result.new(content: 'A', task: @task, agent: :architect)
    ]
    par_result = OrchestraAI::Orchestration::Patterns::ParallelResult.new(results)

    assert_equal results, par_result.to_a
  end

  def test_size_returns_count_of_results
    results = [
      OrchestraAI::Tasks::Result.new(content: 'A', task: @task, agent: :architect),
      OrchestraAI::Tasks::Result.new(content: 'B', task: @task, agent: :implementer)
    ]
    par_result = OrchestraAI::Orchestration::Patterns::ParallelResult.new(results)

    assert_equal 2, par_result.size
  end

  def test_success_rate_returns_zero_for_empty_results
    par_result = OrchestraAI::Orchestration::Patterns::ParallelResult.new([])

    assert_equal 0.0, par_result.success_rate
  end

  def test_total_cost_returns_nil_when_no_costs
    results = [
      OrchestraAI::Tasks::Result.new(content: 'A', task: @task, agent: :architect)
    ]
    par_result = OrchestraAI::Orchestration::Patterns::ParallelResult.new(results)

    assert_nil par_result.total_cost
  end

  def test_failed_returns_true_when_any_failed
    results = [
      OrchestraAI::Tasks::Result.new(content: 'A', task: @task, agent: :architect),
      OrchestraAI::Tasks::Result.new(content: nil, task: @task, agent: :implementer, error: StandardError.new,
                                     success: false)
    ]
    par_result = OrchestraAI::Orchestration::Patterns::ParallelResult.new(results)

    assert par_result.failed?
  end

  def test_total_cost_sums_costs_from_results
    results = [
      OrchestraAI::Tasks::Result.new(
        content: 'A', task: @task, agent: :architect,
        usage: { input_tokens: 100, output_tokens: 50 },
        model: 'gpt-5-mini'
      ),
      OrchestraAI::Tasks::Result.new(
        content: 'B', task: @task, agent: :implementer,
        usage: { input_tokens: 200, output_tokens: 100 },
        model: 'gpt-5-mini'
      )
    ]
    par_result = OrchestraAI::Orchestration::Patterns::ParallelResult.new(results)

    cost = par_result.total_cost
    refute_nil cost
    assert cost[:input] > 0
    assert cost[:output] > 0
    assert cost[:total] > 0
  end
end

class ParallelExecutionTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure do |c|
      c.anthropic_api_key = 'test-key'
      c.openai_api_key = 'test-key'
      c.google_api_key = 'test-key'
    end
    @mock_provider = OrchestraAI::Testing::MockProvider.new(responses: ['Response 1', 'Response 2', 'Response 3'])
    @task1 = OrchestraAI::Tasks::Definition.new(description: 'Task 1')
    @task2 = OrchestraAI::Tasks::Definition.new(description: 'Task 2')
  end

  def test_execute_runs_all_tasks
    pattern = OrchestraAI::Orchestration::Patterns::Parallel.new([@task1, @task2], agent: :implementer)

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      result = pattern.execute

      assert_equal 2, result.size
    end
  end

  def test_execute_with_specific_agent
    pattern = OrchestraAI::Orchestration::Patterns::Parallel.new([@task1], agent: :architect)

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      result = pattern.execute

      assert result.success?
      assert_equal :architect, result.results.first.agent
    end
  end

  def test_execute_handles_task_failures
    error_provider = OrchestraAI::Testing::MockProvider.new(responses: [])
    error_provider.queue_error(StandardError.new('Failed'))
    error_provider.queue_response('Success')

    pattern = OrchestraAI::Orchestration::Patterns::Parallel.new([@task1, @task2], agent: :implementer)

    OrchestraAI::Providers::Registry.stub(:create_for_model, error_provider) do
      result = pattern.execute

      # At least one should fail
      assert result.failures.size >= 1
    end
  end

  def test_execute_without_agent_uses_conductor
    pattern = OrchestraAI::Orchestration::Patterns::Parallel.new([@task1])

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      result = pattern.execute

      # Without explicit agent, conductor auto-routes
      assert result.success?
    end
  end

  def test_execute_with_custom_max_threads
    pattern = OrchestraAI::Orchestration::Patterns::Parallel.new(
      [@task1, @task2],
      agent: :implementer,
      max_threads: 1
    )

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      result = pattern.execute

      assert result.success?
    end
  end

  def test_execute_with_custom_timeout
    pattern = OrchestraAI::Orchestration::Patterns::Parallel.new(
      [@task1],
      agent: :implementer,
      timeout: 5
    )

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      result = pattern.execute

      assert result.success?
    end
  end

  def test_execute_raises_for_unknown_agent
    pattern = OrchestraAI::Orchestration::Patterns::Parallel.new([@task1], agent: :unknown)

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      result = pattern.execute

      # Unknown agent should cause failure in result
      assert result.failed?
    end
  end
end
