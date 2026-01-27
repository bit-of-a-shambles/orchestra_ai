# frozen_string_literal: true

require 'test_helper'

class MemoryTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure { |c| c.anthropic_api_key = 'test-key' }
    @memory = OrchestraAI::Context::Memory.new
  end

  def test_initialise_creates_empty_memory
    assert_empty @memory.conversations
    assert_empty @memory.facts
  end

  def test_conversation_creates_new_conversation
    conv = @memory.conversation('test-id')

    assert_instance_of OrchestraAI::Context::Conversation, conv
    assert_equal 'test-id', conv.id
  end

  def test_conversation_returns_existing_conversation
    conv1 = @memory.conversation('same-id')
    conv2 = @memory.conversation('same-id')

    assert_same conv1, conv2
  end

  def test_remember_stores_fact_with_timestamp
    @memory.remember(:user_name, 'Alice')

    fact = @memory.facts[:user_name]
    assert_equal 'Alice', fact[:value]
    assert_instance_of Time, fact[:timestamp]
  end

  def test_remember_returns_self_for_chaining
    result = @memory.remember(:key, 'value')

    assert_same @memory, result
  end

  def test_recall_returns_stored_value
    @memory.remember(:preference, 'dark_mode')

    assert_equal 'dark_mode', @memory.recall(:preference)
  end

  def test_recall_returns_nil_for_unknown_key
    assert_nil @memory.recall(:nonexistent)
  end

  def test_forget_removes_fact
    @memory.remember(:temp, 'data')
    @memory.forget(:temp)

    assert_nil @memory.recall(:temp)
  end

  def test_forget_returns_self_for_chaining
    @memory.remember(:temp, 'data')
    result = @memory.forget(:temp)

    assert_same @memory, result
  end

  def test_facts_context_returns_formatted_string
    @memory.remember(:name, 'Bob')
    @memory.remember(:role, 'Admin')

    context = @memory.facts_context

    assert_includes context, 'name: Bob'
    assert_includes context, 'role: Admin'
  end

  def test_facts_context_returns_nil_when_empty
    assert_nil @memory.facts_context
  end

  def test_clear_removes_all_data
    @memory.remember(:a, 1)
    @memory.conversation('test')
    @memory.clear

    assert_empty @memory.conversations
    assert_empty @memory.facts
  end

  def test_clear_returns_self_for_chaining
    result = @memory.clear

    assert_same @memory, result
  end

  def test_to_h_exports_memory_state
    @memory.remember(:fact, 'value')
    conv = @memory.conversation('conv-1')
    conv.user('Hello')

    hash = @memory.to_h

    assert hash.key?(:conversations)
    assert hash.key?(:facts)
    assert hash[:facts][:fact][:value] == 'value'
  end

  def test_from_h_imports_facts
    data = { facts: { 'imported' => { value: 'data', timestamp: Time.now } } }

    @memory.from_h(data)

    assert_equal 'data', @memory.facts['imported'][:value]
  end
end
