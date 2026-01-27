# frozen_string_literal: true

require 'test_helper'

class MockProviderTest < Minitest::Test
  include OrchestraAITestHelper

  def test_returns_mock_responses
    provider = OrchestraAI::Testing::MockProvider.new(responses: ['Hello, world!'])
    messages = [{ role: 'user', content: 'Hi' }]

    result = provider.complete(messages)

    assert_equal 'Hello, world!', result[:content]
  end

  def test_records_calls
    provider = OrchestraAI::Testing::MockProvider.new
    messages = [{ role: 'user', content: 'Test message' }]

    provider.complete(messages, temperature: 0.7)

    assert_equal 1, provider.calls.size
    assert_equal :complete, provider.last_call[:method]
    assert_equal 0.7, provider.last_call[:options][:temperature]
  end

  def test_cycles_through_multiple_responses
    provider = OrchestraAI::Testing::MockProvider.new(responses: %w[First Second])
    messages = [{ role: 'user', content: 'Hi' }]

    first = provider.complete(messages)
    second = provider.complete(messages)
    third = provider.complete(messages)

    assert_equal 'First', first[:content]
    assert_equal 'Second', second[:content]
    assert_equal 'First', third[:content]
  end

  def test_queue_error_raises_the_queued_error
    provider = OrchestraAI::Testing::MockProvider.new(responses: [])
    provider.queue_error(StandardError.new('Test error'))
    messages = [{ role: 'user', content: 'Hi' }]

    error = assert_raises(StandardError) { provider.complete(messages) }
    assert_equal 'Test error', error.message
  end

  def test_received_message_checks_if_message_was_received
    provider = OrchestraAI::Testing::MockProvider.new
    provider.complete([{ role: 'user', content: 'Hello there' }])

    assert provider.received_message?('Hello')
    refute provider.received_message?('Goodbye')
  end

  def test_provider_name_returns_mock
    provider = OrchestraAI::Testing::MockProvider.new

    assert_equal :mock, provider.provider_name
  end

  def test_default_model_returns_mock_model
    provider = OrchestraAI::Testing::MockProvider.new

    assert_equal 'mock-model', provider.default_model
  end

  def test_available_models_returns_array
    provider = OrchestraAI::Testing::MockProvider.new

    assert_equal ['mock-model'], provider.available_models
  end

  def test_queue_response_adds_to_queue
    provider = OrchestraAI::Testing::MockProvider.new(responses: ['First'])
    provider.queue_response('Second')
    messages = [{ role: 'user', content: 'Hi' }]

    provider.complete(messages) # First
    result = provider.complete(messages)

    assert_equal 'Second', result[:content]
  end

  def test_queue_response_returns_self_for_chaining
    provider = OrchestraAI::Testing::MockProvider.new

    result = provider.queue_response('Test')

    assert_same provider, result
  end

  def test_clear_calls_removes_call_history
    provider = OrchestraAI::Testing::MockProvider.new
    provider.complete([{ role: 'user', content: 'Hi' }])
    assert_equal 1, provider.calls.size

    provider.clear_calls

    assert_empty provider.calls
  end

  def test_clear_calls_returns_self_for_chaining
    provider = OrchestraAI::Testing::MockProvider.new

    result = provider.clear_calls

    assert_same provider, result
  end

  def test_stream_yields_chunks
    provider = OrchestraAI::Testing::MockProvider.new(responses: ['Hello world'])
    messages = [{ role: 'user', content: 'Hi' }]
    chunks = []

    provider.stream(messages) { |chunk| chunks << chunk }

    assert chunks.size > 0
    assert_equal 'Hello world', chunks.join
  end

  def test_stream_records_call
    provider = OrchestraAI::Testing::MockProvider.new
    messages = [{ role: 'user', content: 'Test' }]

    provider.stream(messages) { |_| }

    assert_equal 1, provider.calls.size
    assert_equal :stream, provider.last_call[:method]
  end

  def test_last_call_returns_nil_when_no_calls
    provider = OrchestraAI::Testing::MockProvider.new

    assert_nil provider.last_call
  end

  def test_build_response_includes_mock_data
    provider = OrchestraAI::Testing::MockProvider.new
    messages = [{ role: 'user', content: 'Hi' }]

    result = provider.complete(messages)

    assert_equal 'mock-model', result[:model]
    assert_equal :mock, result[:provider]
    assert result[:raw][:mock]
  end
end
