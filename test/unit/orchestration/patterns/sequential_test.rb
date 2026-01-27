# frozen_string_literal: true

require 'test_helper'

class SequentialPatternTest < Minitest::Test
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
    pattern = OrchestraAI::Orchestration::Patterns::Sequential.new(task)

    assert_equal 1, pattern.tasks.size
  end

  def test_initialise_with_multiple_tasks
    tasks = [
      OrchestraAI::Tasks::Definition.new(description: 'Task 1'),
      OrchestraAI::Tasks::Definition.new(description: 'Task 2'),
      OrchestraAI::Tasks::Definition.new(description: 'Task 3')
    ]
    pattern = OrchestraAI::Orchestration::Patterns::Sequential.new(tasks)

    assert_equal 3, pattern.tasks.size
  end

  def test_initialise_with_agent_option
    task = OrchestraAI::Tasks::Definition.new(description: 'Task')
    pattern = OrchestraAI::Orchestration::Patterns::Sequential.new(task, agent: :architect)

    assert_equal :architect, pattern.agent
  end

  def test_initialise_with_stop_on_failure_option
    task = OrchestraAI::Tasks::Definition.new(description: 'Task')
    pattern = OrchestraAI::Orchestration::Patterns::Sequential.new(task, stop_on_failure: false)

    refute pattern.instance_variable_get(:@stop_on_failure)
  end

  def test_results_starts_empty
    task = OrchestraAI::Tasks::Definition.new(description: 'Task')
    pattern = OrchestraAI::Orchestration::Patterns::Sequential.new(task)

    assert_empty pattern.results
  end
end

class SequentialResultTest < Minitest::Test
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
    seq_result = OrchestraAI::Orchestration::Patterns::SequentialResult.new(results)

    assert seq_result.success?
    refute seq_result.failed?
  end

  def test_failed_when_any_result_fails
    results = [
      OrchestraAI::Tasks::Result.new(content: 'A', task: @task, agent: :architect),
      OrchestraAI::Tasks::Result.new(content: nil, task: @task, agent: :implementer, error: StandardError.new,
                                     success: false)
    ]
    seq_result = OrchestraAI::Orchestration::Patterns::SequentialResult.new(results)

    refute seq_result.success?
    assert seq_result.failed?
  end

  def test_first_failure_returns_first_failed_result
    failed_result = OrchestraAI::Tasks::Result.new(content: nil, task: @task, agent: :implementer,
                                                   error: StandardError.new, success: false)
    results = [
      OrchestraAI::Tasks::Result.new(content: 'A', task: @task, agent: :architect),
      failed_result
    ]
    seq_result = OrchestraAI::Orchestration::Patterns::SequentialResult.new(results)

    assert_same failed_result, seq_result.first_failure
  end

  def test_last_result_returns_final_result
    last = OrchestraAI::Tasks::Result.new(content: 'Last', task: @task, agent: :reviewer)
    results = [
      OrchestraAI::Tasks::Result.new(content: 'First', task: @task, agent: :architect),
      last
    ]
    seq_result = OrchestraAI::Orchestration::Patterns::SequentialResult.new(results)

    assert_same last, seq_result.last_result
  end

  def test_content_joins_all_results
    results = [
      OrchestraAI::Tasks::Result.new(content: 'Part 1', task: @task, agent: :architect),
      OrchestraAI::Tasks::Result.new(content: 'Part 2', task: @task, agent: :implementer)
    ]
    seq_result = OrchestraAI::Orchestration::Patterns::SequentialResult.new(results)

    content = seq_result.content

    assert_includes content, 'Part 1'
    assert_includes content, 'Part 2'
  end

  def test_to_a_returns_results_array
    results = [
      OrchestraAI::Tasks::Result.new(content: 'A', task: @task, agent: :architect)
    ]
    seq_result = OrchestraAI::Orchestration::Patterns::SequentialResult.new(results)

    assert_equal results, seq_result.to_a
  end

  def test_size_returns_count_of_results
    results = [
      OrchestraAI::Tasks::Result.new(content: 'A', task: @task, agent: :architect),
      OrchestraAI::Tasks::Result.new(content: 'B', task: @task, agent: :implementer),
      OrchestraAI::Tasks::Result.new(content: 'C', task: @task, agent: :reviewer)
    ]
    seq_result = OrchestraAI::Orchestration::Patterns::SequentialResult.new(results)

    assert_equal 3, seq_result.size
  end

  def test_total_cost_returns_nil_when_no_costs
    results = [
      OrchestraAI::Tasks::Result.new(content: 'A', task: @task, agent: :architect)
    ]
    seq_result = OrchestraAI::Orchestration::Patterns::SequentialResult.new(results)

    assert_nil seq_result.total_cost
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
    seq_result = OrchestraAI::Orchestration::Patterns::SequentialResult.new(results)

    cost = seq_result.total_cost
    refute_nil cost
    assert cost[:input] > 0
    assert cost[:output] > 0
    assert cost[:total] > 0
  end
end

class SequentialExecutionTest < Minitest::Test
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

  def test_execute_runs_all_tasks_sequentially
    pattern = OrchestraAI::Orchestration::Patterns::Sequential.new([@task1, @task2], agent: :implementer)

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      result = pattern.execute

      assert result.success?
      assert_equal 2, result.size
    end
  end

  def test_execute_stops_on_failure_by_default
    error_provider = OrchestraAI::Testing::MockProvider.new(responses: [])
    error_provider.queue_error(StandardError.new('Failed'))
    error_provider.queue_response('Success')

    pattern = OrchestraAI::Orchestration::Patterns::Sequential.new([@task1, @task2], agent: :implementer)

    OrchestraAI::Providers::Registry.stub(:create_for_model, error_provider) do
      result = pattern.execute

      assert result.failed?
      assert_equal 1, result.size  # Stopped after first failure
    end
  end

  def test_execute_continues_on_failure_when_stop_on_failure_false
    error_provider = OrchestraAI::Testing::MockProvider.new(responses: [])
    error_provider.queue_error(StandardError.new('Failed'))
    error_provider.queue_response('Success')

    pattern = OrchestraAI::Orchestration::Patterns::Sequential.new(
      [@task1, @task2],
      agent: :implementer,
      stop_on_failure: false
    )

    OrchestraAI::Providers::Registry.stub(:create_for_model, error_provider) do
      result = pattern.execute

      assert result.failed?
      assert_equal 2, result.size  # Continued despite failure
    end
  end

  def test_execute_with_specific_agent
    pattern = OrchestraAI::Orchestration::Patterns::Sequential.new([@task1], agent: :architect)

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      result = pattern.execute

      assert result.success?
      assert_equal :architect, result.results.first.agent
    end
  end

  def test_execute_passes_context_between_tasks
    pattern = OrchestraAI::Orchestration::Patterns::Sequential.new([@task1, @task2], agent: :implementer)

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      result = pattern.execute

      # Verify second task received context from first result
      assert_equal 2, @mock_provider.calls.size
      second_call_messages = @mock_provider.calls[1][:messages]
      message_text = second_call_messages.map { |m| m[:content] }.join
      assert_includes message_text, 'Response 1'
    end
  end

  def test_execute_raises_for_unknown_agent
    pattern = OrchestraAI::Orchestration::Patterns::Sequential.new([@task1], agent: :unknown)

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      assert_raises(ArgumentError) { pattern.execute }
    end
  end

  def test_execute_without_agent_uses_conductor
    pattern = OrchestraAI::Orchestration::Patterns::Sequential.new([@task1])

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      result = pattern.execute

      # Without explicit agent, conductor auto-routes
      assert result.success?
    end
  end
end
