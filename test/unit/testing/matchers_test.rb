# frozen_string_literal: true

require 'test_helper'

class MatchersTest < Minitest::Test
  include OrchestraAITestHelper
  include OrchestraAI::Testing::Matchers

  class MockResult
    attr_accessor :agent, :model, :error

    def initialize(agent:, model:, success: true, error: nil)
      @agent = agent.to_sym
      @model = model
      @success = success
      @error = error
    end

    def success?
      @success
    end
  end

  # Tests for Assertions module
  def test_assert_used_agent_passes_when_agent_matches
    result = MockResult.new(agent: :architect, model: 'gpt-4')

    assert_used_agent(:architect, result)
  end

  def test_assert_used_agent_accepts_string_agent
    result = MockResult.new(agent: :architect, model: 'gpt-4')

    assert_used_agent('architect', result)
  end

  def test_refute_used_agent_passes_when_agent_differs
    result = MockResult.new(agent: :architect, model: 'gpt-4')

    refute_used_agent(:implementer, result)
  end

  def test_assert_used_model_passes_when_model_matches
    result = MockResult.new(agent: :architect, model: 'gpt-4')

    assert_used_model('gpt-4', result)
  end

  def test_refute_used_model_passes_when_model_differs
    result = MockResult.new(agent: :architect, model: 'gpt-4')

    refute_used_model('gpt-3.5-turbo', result)
  end

  def test_assert_classified_as_with_simple_task
    task = OrchestraAI::Tasks::Definition.new(
      description: 'fix typo',
      context: {}
    )

    assert_classified_as(:simple, task)
  end

  def test_refute_classified_as_when_tier_differs
    task = OrchestraAI::Tasks::Definition.new(
      description: 'fix typo',
      context: {}
    )

    refute_classified_as(:complex, task)
  end

  def test_assert_successful_passes_when_result_succeeds
    result = MockResult.new(agent: :architect, model: 'gpt-4', success: true)

    assert_successful(result)
  end

  def test_refute_successful_passes_when_result_fails
    result = MockResult.new(agent: :architect, model: 'gpt-4', success: false)

    refute_successful(result)
  end

  def test_assert_failed_is_alias_for_refute_successful
    result = MockResult.new(agent: :architect, model: 'gpt-4', success: false)

    assert_failed(result)
  end

  # Tests for Matchers module
  def test_have_used_agent_matches_when_agent_matches
    matcher = have_used_agent(:architect)
    result = MockResult.new(agent: :architect, model: 'gpt-4')

    assert matcher.matches?(result)
  end

  def test_have_used_agent_does_not_match_when_agent_differs
    matcher = have_used_agent(:implementer)
    result = MockResult.new(agent: :architect, model: 'gpt-4')

    refute matcher.matches?(result)
  end

  def test_have_used_agent_failure_message
    matcher = have_used_agent(:implementer)
    result = MockResult.new(agent: :architect, model: 'gpt-4')
    matcher.matches?(result)

    message = matcher.failure_message

    assert_includes message, 'implementer'
    assert_includes message, 'architect'
  end

  def test_have_used_agent_failure_message_when_negated
    matcher = have_used_agent(:architect)
    result = MockResult.new(agent: :architect, model: 'gpt-4')
    matcher.matches?(result)

    message = matcher.failure_message_when_negated

    assert_includes message, 'architect'
  end

  def test_have_used_model_matches_when_model_matches
    matcher = have_used_model('gpt-4')
    result = MockResult.new(agent: :architect, model: 'gpt-4')

    assert matcher.matches?(result)
  end

  def test_have_used_model_does_not_match_when_model_differs
    matcher = have_used_model('claude-3')
    result = MockResult.new(agent: :architect, model: 'gpt-4')

    refute matcher.matches?(result)
  end

  def test_have_used_model_failure_message
    matcher = have_used_model('claude-3')
    result = MockResult.new(agent: :architect, model: 'gpt-4')
    matcher.matches?(result)

    message = matcher.failure_message

    assert_includes message, 'claude-3'
    assert_includes message, 'gpt-4'
  end

  def test_have_used_model_failure_message_when_negated
    matcher = have_used_model('gpt-4')
    result = MockResult.new(agent: :architect, model: 'gpt-4')
    matcher.matches?(result)

    message = matcher.failure_message_when_negated

    assert_includes message, 'gpt-4'
  end

  def test_be_classified_as_matches_when_tier_matches
    task = OrchestraAI::Tasks::Definition.new(
      description: 'fix typo',
      context: {}
    )
    matcher = be_classified_as(:simple)

    assert matcher.matches?(task)
  end

  def test_be_classified_as_does_not_match_when_tier_differs
    task = OrchestraAI::Tasks::Definition.new(
      description: 'fix typo',
      context: {}
    )
    matcher = be_classified_as(:complex)

    refute matcher.matches?(task)
  end

  def test_be_classified_as_failure_message
    task = OrchestraAI::Tasks::Definition.new(
      description: 'fix typo',
      context: {}
    )
    matcher = be_classified_as(:complex)
    matcher.matches?(task)

    message = matcher.failure_message

    assert_includes message, 'complex'
    assert_includes message, 'simple'
  end

  def test_be_classified_as_failure_message_when_negated
    task = OrchestraAI::Tasks::Definition.new(
      description: 'fix typo',
      context: {}
    )
    matcher = be_classified_as(:simple)
    matcher.matches?(task)

    message = matcher.failure_message_when_negated

    assert_includes message, 'simple'
  end

  def test_be_successful_matches_when_result_succeeds
    result = MockResult.new(agent: :architect, model: 'gpt-4', success: true)
    matcher = be_successful

    assert matcher.matches?(result)
  end

  def test_be_successful_does_not_match_when_result_fails
    result = MockResult.new(agent: :architect, model: 'gpt-4', success: false)
    matcher = be_successful

    refute matcher.matches?(result)
  end

  def test_be_successful_failure_message
    result = MockResult.new(agent: :architect, model: 'gpt-4', success: false)
    matcher = be_successful
    matcher.matches?(result)

    message = matcher.failure_message

    assert_includes message, 'successful'
  end

  def test_be_successful_failure_message_includes_error
    error = StandardError.new('Something went wrong')
    result = MockResult.new(agent: :architect, model: 'gpt-4', success: false, error: error)
    matcher = be_successful
    matcher.matches?(result)

    message = matcher.failure_message

    assert_includes message, 'Something went wrong'
  end

  def test_be_successful_failure_message_when_negated
    result = MockResult.new(agent: :architect, model: 'gpt-4', success: true)
    matcher = be_successful
    matcher.matches?(result)

    message = matcher.failure_message_when_negated

    assert_includes message, 'not to be successful'
  end
end
