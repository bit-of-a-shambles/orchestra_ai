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
end
