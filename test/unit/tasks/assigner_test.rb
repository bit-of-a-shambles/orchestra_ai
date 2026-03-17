# frozen_string_literal: true

require 'test_helper'

class AssignerTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure do |c|
      c.anthropic_api_key = 'test-key'
      c.openai_api_key = 'test-key'
      c.google_api_key = 'test-key'
    end
  end

  def test_assign_sets_model_on_task
    task = OrchestraAI::Tasks::Definition.new(description: 'Simple fix')

    OrchestraAI::Tasks::Assigner.assign(task, agent: :architect)

    refute_nil task.assigned_model
  end

  def test_assign_sets_agent_on_task
    task = OrchestraAI::Tasks::Definition.new(description: 'Simple task')

    OrchestraAI::Tasks::Assigner.assign(task, agent: :implementer)

    assert_equal :implementer, task.assigned_agent
  end

  def test_assign_sets_difficulty_on_task
    task = OrchestraAI::Tasks::Definition.new(description: 'Test task')

    OrchestraAI::Tasks::Assigner.assign(task, agent: :reviewer)

    refute_nil task.difficulty
  end

  def test_assign_returns_model_name
    task = OrchestraAI::Tasks::Definition.new(description: 'Task')

    model = OrchestraAI::Tasks::Assigner.assign(task, agent: :architect)

    assert_instance_of String, model
  end

  def test_assign_batch_assigns_multiple_tasks
    tasks = [
      OrchestraAI::Tasks::Definition.new(description: 'Task 1'),
      OrchestraAI::Tasks::Definition.new(description: 'Task 2'),
      OrchestraAI::Tasks::Definition.new(description: 'Task 3')
    ]

    assignments = OrchestraAI::Tasks::Assigner.assign_batch(tasks, agent: :implementer)

    assert_equal 3, assignments.size
    tasks.each do |task|
      assert assignments.key?(task.id)
      refute_nil task.assigned_model
    end
  end

  def test_estimate_cost_returns_nil_without_model
    task = OrchestraAI::Tasks::Definition.new(description: 'Task')

    estimate = OrchestraAI::Tasks::Assigner.estimate_cost(task)

    assert_nil estimate
  end

  def test_estimate_cost_returns_hash_with_model
    task = OrchestraAI::Tasks::Definition.new(description: 'Test task for estimation')
    OrchestraAI::Tasks::Assigner.assign(task, agent: :architect)

    estimate = OrchestraAI::Tasks::Assigner.estimate_cost(task)

    refute_nil estimate
    assert estimate.key?(:input_tokens)
    assert estimate.key?(:output_tokens)
    assert estimate.key?(:input_cost)
    assert estimate.key?(:output_cost)
    assert estimate.key?(:total_cost)
    assert estimate.key?(:model)
  end

  def test_estimate_cost_with_explicit_model
    task = OrchestraAI::Tasks::Definition.new(description: 'Task')

    estimate = OrchestraAI::Tasks::Assigner.estimate_cost(task, model: 'claude-opus-4.6')

    refute_nil estimate
    assert_equal 'claude-opus-4.6', estimate[:model]
  end

  def test_estimate_cost_includes_context_in_calculation
    task = OrchestraAI::Tasks::Definition.new(
      description: 'Task',
      context: ['Previous context that should add to token count']
    )
    task_without_context = OrchestraAI::Tasks::Definition.new(description: 'Task')

    OrchestraAI::Tasks::Assigner.assign(task, agent: :architect)
    OrchestraAI::Tasks::Assigner.assign(task_without_context, agent: :architect)

    with_context = OrchestraAI::Tasks::Assigner.estimate_cost(task)
    without_context = OrchestraAI::Tasks::Assigner.estimate_cost(task_without_context)

    assert with_context[:input_tokens] > without_context[:input_tokens]
  end

  def test_simple_task_gets_simple_model
    task = OrchestraAI::Tasks::Definition.new(description: 'Fix typo')

    model = OrchestraAI::Tasks::Assigner.assign(task, agent: :implementer)

    # Simple tasks should get the simple tier model
    simple_model = OrchestraAI.configuration.models.implementer.simple
    assert_equal simple_model, model
  end

  def test_complex_task_gets_complex_model
    # Create a clearly complex task
    task = OrchestraAI::Tasks::Definition.new(
      description: 'Design a distributed microservices architecture with event-driven communication, implementing CQRS pattern with event sourcing for data consistency across multiple domains',
      difficulty: 0.95 # Force high difficulty
    )

    model = OrchestraAI::Tasks::Assigner.assign(task, agent: :architect)

    # Complex tasks should get the complex tier model
    complex_model = OrchestraAI.configuration.models.architect.complex
    assert_equal complex_model, model
  end

  def test_assign_finds_fallback_when_primary_model_unavailable
    # Configure with only Google API key but mock the model availability
    OrchestraAI.reset_configuration!
    OrchestraAI.configure do |c|
      c.anthropic_api_key = nil
      c.openai_api_key = nil
      c.google_api_key = 'test-key'
    end

    task = OrchestraAI::Tasks::Definition.new(
      description: 'Complex task requiring fallback',
      difficulty: 0.95
    )

    model = OrchestraAI::Tasks::Assigner.assign(task, agent: :architect)

    # Should fall back to Google model since that's the only available provider
    refute_nil model
  end

  def test_estimate_cost_returns_nil_for_unknown_model
    task = OrchestraAI::Tasks::Definition.new(description: 'Task')
    task.assigned_model = 'unknown-model'

    estimate = OrchestraAI::Tasks::Assigner.estimate_cost(task)

    assert_nil estimate
  end
end
