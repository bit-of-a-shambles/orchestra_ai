# frozen_string_literal: true

require 'test_helper'

class ConversationTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure { |c| c.anthropic_api_key = 'test-key' }
    @conversation = OrchestraAI::Context::Conversation.new
  end

  def test_initialise_creates_empty_conversation
    assert_empty @conversation.messages
    assert_empty @conversation.results
  end

  def test_initialise_generates_uuid_by_default
    assert_match(/\A[0-9a-f-]{36}\z/, @conversation.id)
  end

  def test_initialise_accepts_custom_id
    conv = OrchestraAI::Context::Conversation.new(id: 'custom-id')

    assert_equal 'custom-id', conv.id
  end

  def test_user_adds_user_message
    @conversation.user('Hello')

    assert_equal 1, @conversation.messages.size
    assert_equal :user, @conversation.messages.first[:role]
    assert_equal 'Hello', @conversation.messages.first[:content]
  end

  def test_assistant_adds_assistant_message
    @conversation.assistant('Hi there')

    assert_equal 1, @conversation.messages.size
    assert_equal :assistant, @conversation.messages.first[:role]
    assert_equal 'Hi there', @conversation.messages.first[:content]
  end

  def test_system_adds_system_message
    @conversation.system('You are helpful')

    assert_equal 1, @conversation.messages.size
    assert_equal :system, @conversation.messages.first[:role]
  end

  def test_chaining_works
    result = @conversation.user('Hello').assistant('Hi')

    assert_same @conversation, result
    assert_equal 2, @conversation.messages.size
  end

  def test_to_messages_returns_formatted_array
    @conversation.user('Question')
    @conversation.assistant('Answer')

    messages = @conversation.to_messages

    assert_equal 2, messages.size
    assert_equal 'user', messages.first[:role]
    assert_equal 'Question', messages.first[:content]
  end

  def test_clear_removes_all_messages_and_results
    @conversation.user('Test')
    @conversation.clear

    assert_empty @conversation.messages
    assert_empty @conversation.results
  end

  def test_estimated_tokens_calculates_based_on_content_length
    @conversation.user('Hello world') # 11 chars / 4 ≈ 2 tokens

    tokens = @conversation.estimated_tokens

    assert tokens.positive?
  end

  def test_truncate_removes_messages_when_over_limit
    # Add many messages to exceed token limit
    100.times { |i| @conversation.user("Message #{i} with some extra content to add tokens") }
    initial_count = @conversation.messages.size

    @conversation.truncate(max_tokens: 50)

    assert @conversation.messages.size < initial_count
  end

  def test_to_context_returns_empty_array_when_no_results
    context = @conversation.to_context

    assert_equal [], context
  end

  def test_created_at_is_set
    assert_instance_of Time, @conversation.created_at
  end

  def test_add_result_stores_result
    task = OrchestraAI::Tasks::Definition.new(description: 'Test')
    result = OrchestraAI::Tasks::Result.new(
      content: 'Success response',
      task: task,
      agent: :architect
    )

    @conversation.add_result(result)

    assert_equal 1, @conversation.results.size
    assert_same result, @conversation.results.first
  end

  def test_add_result_adds_assistant_message_for_success
    task = OrchestraAI::Tasks::Definition.new(description: 'Test')
    result = OrchestraAI::Tasks::Result.new(
      content: 'Success response',
      task: task,
      agent: :architect
    )

    @conversation.add_result(result)

    assert_equal 1, @conversation.messages.size
    assert_equal :assistant, @conversation.messages.first[:role]
    assert_equal 'Success response', @conversation.messages.first[:content]
  end

  def test_add_result_does_not_add_message_for_failed_result
    task = OrchestraAI::Tasks::Definition.new(description: 'Test')
    result = OrchestraAI::Tasks::Result.new(
      content: nil,
      task: task,
      agent: :architect,
      error: StandardError.new('Failed'),
      success: false
    )

    @conversation.add_result(result)

    assert_equal 1, @conversation.results.size
    assert_empty @conversation.messages
  end

  def test_add_result_returns_self_for_chaining
    task = OrchestraAI::Tasks::Definition.new(description: 'Test')
    result = OrchestraAI::Tasks::Result.new(content: 'Test', task: task, agent: :architect)

    returned = @conversation.add_result(result)

    assert_same @conversation, returned
  end

  def test_create_task_returns_definition_with_context
    task1 = OrchestraAI::Tasks::Definition.new(description: 'Task 1')
    result = OrchestraAI::Tasks::Result.new(
      content: 'Result content',
      task: task1,
      agent: :architect,
      model: 'gemini-2.5-flash'
    )
    @conversation.add_result(result)

    new_task = @conversation.create_task('New task description')

    assert_instance_of OrchestraAI::Tasks::Definition, new_task
    assert_equal 'New task description', new_task.description
    refute_empty new_task.context
  end

  def test_to_context_returns_contexts_from_successful_results
    task = OrchestraAI::Tasks::Definition.new(description: 'Test')
    success_result = OrchestraAI::Tasks::Result.new(
      content: 'Success',
      task: task,
      agent: :architect,
      model: 'gemini-2.5-flash'
    )
    failed_result = OrchestraAI::Tasks::Result.new(
      content: nil,
      task: task,
      agent: :architect,
      error: StandardError.new('Failed'),
      success: false
    )

    @conversation.add_result(success_result)
    @conversation.add_result(failed_result)

    context = @conversation.to_context

    assert_equal 1, context.size
    assert_includes context.first, 'Success'
  end
end
