# frozen_string_literal: true

require 'test_helper'

class CircuitBreakerTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure { |c| c.anthropic_api_key = 'test-key' }
  end

  def test_initialise_with_defaults_from_config
    breaker = OrchestraAI::Reliability::CircuitBreaker.new(name: 'test')

    assert_equal 'test', breaker.name
    assert_equal OrchestraAI.configuration.circuit_breaker.failure_threshold,
                 breaker.instance_variable_get(:@failure_threshold)
  end

  def test_initialise_with_custom_values
    breaker = OrchestraAI::Reliability::CircuitBreaker.new(
      name: 'custom',
      failure_threshold: 3,
      reset_timeout: 30
    )

    assert_equal 3, breaker.instance_variable_get(:@failure_threshold)
    assert_equal 30, breaker.instance_variable_get(:@reset_timeout)
  end

  def test_starts_in_closed_state
    breaker = OrchestraAI::Reliability::CircuitBreaker.new(name: 'test')

    assert breaker.closed?
    refute breaker.open?
    refute breaker.half_open?
  end

  def test_execute_returns_block_result_when_closed
    breaker = OrchestraAI::Reliability::CircuitBreaker.new(name: 'test')

    result = breaker.execute { 'success' }

    assert_equal 'success', result
  end

  def test_opens_after_failure_threshold
    breaker = OrchestraAI::Reliability::CircuitBreaker.new(
      name: 'test',
      failure_threshold: 3
    )

    3.times do
      breaker.execute { raise StandardError, 'fail' }
    rescue StandardError
      nil
    end

    assert breaker.open?
  end

  def test_raises_circuit_open_error_when_open
    breaker = OrchestraAI::Reliability::CircuitBreaker.new(
      name: 'test',
      failure_threshold: 1
    )

    begin
      breaker.execute { raise StandardError, 'fail' }
    rescue StandardError
      nil
    end

    assert_raises(OrchestraAI::CircuitOpenError) do
      breaker.execute { 'should not execute' }
    end
  end

  def test_resets_failure_count_on_success
    breaker = OrchestraAI::Reliability::CircuitBreaker.new(
      name: 'test',
      failure_threshold: 3
    )

    2.times do
      breaker.execute { raise StandardError }
    rescue StandardError
      nil
    end
    breaker.execute { 'success' }

    assert_equal 0, breaker.failure_count.value
    assert breaker.closed?
  end

  def test_enters_half_open_after_reset_timeout
    breaker = OrchestraAI::Reliability::CircuitBreaker.new(
      name: 'test',
      failure_threshold: 1,
      reset_timeout: 0.01
    )

    begin
      breaker.execute { raise StandardError }
    rescue StandardError
      nil
    end
    assert breaker.open?

    sleep 0.02

    # Calling allow_request? or check_state! transitions to half_open
    assert breaker.allow_request?
  end

  def test_closes_from_half_open_on_success
    breaker = OrchestraAI::Reliability::CircuitBreaker.new(
      name: 'test',
      failure_threshold: 1,
      reset_timeout: 0.01
    )

    begin
      breaker.execute { raise StandardError }
    rescue StandardError
      nil
    end
    sleep 0.02

    breaker.execute { 'success' }

    assert breaker.closed?
  end

  def test_reopens_from_half_open_on_failure
    breaker = OrchestraAI::Reliability::CircuitBreaker.new(
      name: 'test',
      failure_threshold: 1,
      reset_timeout: 0.01
    )

    begin
      breaker.execute { raise StandardError }
    rescue StandardError
      nil
    end
    sleep 0.02

    begin
      breaker.execute { raise StandardError }
    rescue StandardError
      nil
    end

    assert breaker.open?
  end

  def test_reset_clears_state
    breaker = OrchestraAI::Reliability::CircuitBreaker.new(
      name: 'test',
      failure_threshold: 1
    )

    begin
      breaker.execute { raise StandardError }
    rescue StandardError
      nil
    end
    assert breaker.open?

    breaker.reset

    assert breaker.closed?
    assert_equal 0, breaker.failure_count.value
  end

  def test_trip_forces_circuit_open
    breaker = OrchestraAI::Reliability::CircuitBreaker.new(name: 'test')

    breaker.trip!

    assert breaker.open?
  end

  def test_state_returns_current_state
    breaker = OrchestraAI::Reliability::CircuitBreaker.new(name: 'test')

    assert_equal :closed, breaker.state
  end

  def test_allow_request_returns_true_when_closed
    breaker = OrchestraAI::Reliability::CircuitBreaker.new(name: 'test')

    assert breaker.allow_request?
  end

  def test_allow_request_returns_false_when_open_and_not_timed_out
    breaker = OrchestraAI::Reliability::CircuitBreaker.new(
      name: 'test',
      failure_threshold: 1,
      reset_timeout: 60 # Long timeout so it won't elapse
    )

    breaker.trip!

    refute breaker.allow_request?
  end

  def test_allow_request_returns_true_when_half_open
    breaker = OrchestraAI::Reliability::CircuitBreaker.new(
      name: 'test',
      failure_threshold: 1,
      reset_timeout: 0.01
    )

    breaker.trip!
    sleep 0.02 # Wait for reset timeout

    # allow_request? returns true when reset timeout has passed (transition happens internally)
    result = breaker.allow_request?

    # The circuit should transition to half_open and allow the request
    assert result
  end

  def test_allow_request_in_half_open_state
    breaker = OrchestraAI::Reliability::CircuitBreaker.new(
      name: 'test',
      failure_threshold: 1,
      reset_timeout: 0.01
    )

    breaker.trip!
    sleep 0.02

    # First call transitions to half_open
    breaker.execute { 'success' }

    # Now trip again and wait to get to half_open
    breaker.trip!
    sleep 0.02

    # Execute to transition to half_open, then check allow_request? in half_open state
    begin
      breaker.execute { raise StandardError }
    rescue StandardError
      # Ignore
    end

    # After a failure in half_open, it goes back to open
    # Let's directly set to half_open using internal methods for testing
    breaker.instance_variable_set(:@state, :half_open)
    assert breaker.half_open?
    assert breaker.allow_request?
  end
end

class CircuitBreakerRegistryTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure { |c| c.anthropic_api_key = 'test-key' }
  end

  def test_for_provider_returns_circuit_breaker
    breaker = OrchestraAI::Reliability::CircuitBreakerRegistry.for_provider('anthropic')

    assert_instance_of OrchestraAI::Reliability::CircuitBreaker, breaker
  end

  def test_for_provider_returns_same_breaker_for_same_provider
    breaker1 = OrchestraAI::Reliability::CircuitBreakerRegistry.for_provider('openai')
    breaker2 = OrchestraAI::Reliability::CircuitBreakerRegistry.for_provider('openai')

    assert_same breaker1, breaker2
  end

  def test_reset_all_resets_all_breakers
    breaker = OrchestraAI::Reliability::CircuitBreakerRegistry.for_provider('test-provider')
    breaker.trip!
    assert breaker.open?

    OrchestraAI::Reliability::CircuitBreakerRegistry.reset_all

    assert breaker.closed?
  end
end
