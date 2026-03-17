# frozen_string_literal: true

require 'test_helper'

class ResultTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure do |c|
      c.anthropic_api_key = 'test-key'
      c.openai_api_key = 'test-key'
      c.google_api_key = 'test-key'
    end
    @task = OrchestraAI::Tasks::Definition.new(description: 'Test task')
  end

  def test_successful_result
    result = OrchestraAI::Tasks::Result.new(
      content: 'Success content',
      task: @task,
      agent: :architect,
      model: 'claude-opus-4.6'
    )

    assert result.success?
    refute result.failed?
    assert_equal 'Success content', result.content
    assert_equal :architect, result.agent
    assert_equal 'claude-opus-4.6', result.model
  end

  def test_failed_result_with_error
    error = StandardError.new('Test error')
    result = OrchestraAI::Tasks::Result.new(
      content: nil,
      task: @task,
      agent: :implementer,
      error: error,
      success: false
    )

    refute result.success?
    assert result.failed?
    assert_equal error, result.error
  end

  def test_to_h_returns_hash_representation
    result = OrchestraAI::Tasks::Result.new(
      content: 'Content',
      task: @task,
      agent: :reviewer,
      model: 'gpt-4.1',
      usage: { input_tokens: 100, output_tokens: 200 }
    )

    hash = result.to_h

    assert_equal @task.id, hash[:task_id]
    assert_equal :reviewer, hash[:agent]
    assert_equal 'gpt-4.1', hash[:model]
    assert hash[:success]
    assert_equal 'Content', hash[:content]
    assert_nil hash[:error]
  end

  def test_to_h_includes_error_message_when_failed
    error = StandardError.new('Something went wrong')
    result = OrchestraAI::Tasks::Result.new(
      content: nil,
      task: @task,
      agent: :architect,
      error: error,
      success: false
    )

    hash = result.to_h

    assert_equal 'Something went wrong', hash[:error]
    refute hash[:success]
  end

  def test_to_context_returns_formatted_string_for_success
    result = OrchestraAI::Tasks::Result.new(
      content: 'Implementation code here',
      task: @task,
      agent: :implementer,
      model: 'gemini-2.5-flash'
    )

    context = result.to_context

    assert_includes context, 'Agent: implementer'
    assert_includes context, 'Model: gemini-2.5-flash'
    assert_includes context, 'Implementation code here'
  end

  def test_to_context_returns_nil_for_failed_result
    result = OrchestraAI::Tasks::Result.new(
      content: nil,
      task: @task,
      agent: :architect,
      error: StandardError.new('Failed'),
      success: false
    )

    assert_nil result.to_context
  end

  def test_usage_defaults_to_empty_hash
    result = OrchestraAI::Tasks::Result.new(
      content: 'Test',
      task: @task,
      agent: :architect
    )

    assert_equal({}, result.usage)
  end

  def test_metadata_defaults_to_empty_hash
    result = OrchestraAI::Tasks::Result.new(
      content: 'Test',
      task: @task,
      agent: :architect
    )

    assert_equal({}, result.metadata)
  end

  def test_result_with_usage_data
    result = OrchestraAI::Tasks::Result.new(
      content: 'Test',
      task: @task,
      agent: :architect,
      usage: { input_tokens: 100, output_tokens: 50 }
    )

    assert_equal 100, result.usage[:input_tokens]
    assert_equal 50, result.usage[:output_tokens]
  end

  def test_completed_at_is_set
    result = OrchestraAI::Tasks::Result.new(
      content: 'Test',
      task: @task,
      agent: :architect
    )

    assert_instance_of Time, result.completed_at
  end

  def test_cost_returns_nil_without_usage_tokens
    result = OrchestraAI::Tasks::Result.new(
      content: 'Test',
      task: @task,
      agent: :architect,
      model: 'claude-opus-4.6'
    )

    assert_nil result.cost
  end

  def test_cost_calculates_with_usage_tokens
    result = OrchestraAI::Tasks::Result.new(
      content: 'Test',
      task: @task,
      agent: :architect,
      model: 'claude-opus-4.6',
      usage: { input_tokens: 1_000_000, output_tokens: 1_000_000 }
    )

    cost = result.cost

    refute_nil cost
    assert cost[:input] > 0
    assert cost[:output] > 0
    assert_equal cost[:input] + cost[:output], cost[:total]
  end

  def test_duration_returns_nil_without_task_created_at
    @task.instance_variable_set(:@created_at, nil)
    result = OrchestraAI::Tasks::Result.new(
      content: 'Test',
      task: @task,
      agent: :architect
    )

    assert_nil result.duration
  end

  def test_duration_calculates_time_difference
    result = OrchestraAI::Tasks::Result.new(
      content: 'Test',
      task: @task,
      agent: :architect
    )

    # Duration should be very small but non-negative
    duration = result.duration
    refute_nil duration
    assert duration >= 0
  end
end
