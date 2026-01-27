# frozen_string_literal: true

require 'test_helper'

class DefinitionTest < Minitest::Test
  include OrchestraAITestHelper

  def test_creates_task_with_description
    task = OrchestraAI::Tasks::Definition.new(description: 'Test task')

    assert_equal 'Test task', task.description
    refute_nil task.id
    assert_equal [], task.context
    assert_equal({}, task.metadata)
  end

  def test_raises_error_without_description
    assert_raises(OrchestraAI::TaskValidationError) do
      OrchestraAI::Tasks::Definition.new(description: '')
    end
  end

  def test_accepts_custom_id
    task = OrchestraAI::Tasks::Definition.new(description: 'Test', id: 'custom-id')

    assert_equal 'custom-id', task.id
  end

  def test_accepts_context
    task = OrchestraAI::Tasks::Definition.new(
      description: 'Test',
      context: ['Previous result']
    )

    assert_equal ['Previous result'], task.context
  end

  def test_add_context_adds_to_task
    task = OrchestraAI::Tasks::Definition.new(description: 'Test')
    task.add_context('New context')

    assert_includes task.context, 'New context'
  end

  def test_add_context_returns_self_for_chaining
    task = OrchestraAI::Tasks::Definition.new(description: 'Test')
    result = task.add_context('Context')

    assert_same task, result
  end

  def test_dup_with_creates_copy_with_overrides
    original = OrchestraAI::Tasks::Definition.new(
      description: 'Original',
      difficulty: 0.5
    )

    copy = original.dup_with(description: 'Modified')

    assert_equal 'Modified', copy.description
    assert_equal 0.5, copy.difficulty
    refute_equal original.id, copy.id
  end
end
