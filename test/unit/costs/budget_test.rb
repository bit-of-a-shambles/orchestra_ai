# frozen_string_literal: true

require 'test_helper'

class BudgetTest < Minitest::Test
  def setup
    @budget = OrchestraAI::Costs::Budget.new(
      limits: { anthropic: 10.0, openai: 5.0, google: 2.0 },
      alert_threshold: 0.8
    )
  end

  # Initialization tests
  def test_initialize_with_limits
    assert_equal 10.0, @budget.limits[:anthropic]
    assert_equal 5.0, @budget.limits[:openai]
    assert_equal 2.0, @budget.limits[:google]
  end

  def test_initialize_with_string_keys
    budget = OrchestraAI::Costs::Budget.new(
      limits: { 'anthropic' => 10.0, 'openai' => 5.0 }
    )

    assert_equal 10.0, budget.limits[:anthropic]
    assert_equal 5.0, budget.limits[:openai]
  end

  def test_initialize_with_default_alert_threshold
    budget = OrchestraAI::Costs::Budget.new
    assert_equal 0.8, budget.alert_threshold
  end

  def test_initialize_with_custom_alert_threshold
    assert_equal 0.8, @budget.alert_threshold
  end

  def test_initialize_with_empty_limits
    budget = OrchestraAI::Costs::Budget.new
    assert_nil budget.limits[:anthropic]
    assert_nil budget.limits[:openai]
    assert_nil budget.limits[:google]
  end

  # Remaining tests
  def test_remaining_for_specific_provider
    assert_equal 10.0, @budget.remaining(:anthropic)
    assert_equal 5.0, @budget.remaining(:openai)
  end

  def test_remaining_for_all_providers
    remaining = @budget.remaining

    assert_equal 10.0, remaining[:anthropic]
    assert_equal 5.0, remaining[:openai]
    assert_equal 2.0, remaining[:google]
  end

  def test_remaining_after_spend
    @budget.record_spend(3.0, :anthropic)

    assert_equal 7.0, @budget.remaining(:anthropic)
  end

  def test_remaining_returns_zero_not_negative
    @budget.record_spend(15.0, :anthropic)

    assert_equal 0.0, @budget.remaining(:anthropic)
  end

  def test_remaining_returns_infinity_when_no_limit
    budget = OrchestraAI::Costs::Budget.new

    assert_equal Float::INFINITY, budget.remaining(:anthropic)
  end

  def test_remaining_with_string_provider
    assert_equal 10.0, @budget.remaining('anthropic')
  end

  def test_remaining_raises_for_invalid_provider
    assert_raises(ArgumentError) do
      @budget.remaining(:invalid)
    end
  end

  # Can afford tests
  def test_can_afford_when_sufficient_budget
    assert @budget.can_afford?(5.0, :anthropic)
  end

  def test_can_afford_when_exactly_equal
    assert @budget.can_afford?(10.0, :anthropic)
  end

  def test_cannot_afford_when_insufficient
    refute @budget.can_afford?(15.0, :anthropic)
  end

  def test_can_afford_with_no_limit_set
    budget = OrchestraAI::Costs::Budget.new

    assert budget.can_afford?(1000.0, :anthropic)
  end

  def test_can_afford_with_string_provider
    assert @budget.can_afford?(5.0, 'anthropic')
  end

  def test_can_afford_raises_for_invalid_provider
    assert_raises(ArgumentError) do
      @budget.can_afford?(5.0, :invalid)
    end
  end

  # Record spend tests
  def test_record_spend_updates_spent_amount
    @budget.record_spend(3.0, :anthropic)

    assert_equal 3.0, @budget.spent[:anthropic]
  end

  def test_record_spend_accumulates
    @budget.record_spend(2.0, :anthropic)
    @budget.record_spend(3.0, :anthropic)

    assert_equal 5.0, @budget.spent[:anthropic]
  end

  def test_record_spend_returns_total_spent
    result = @budget.record_spend(3.0, :anthropic)

    assert_equal 3.0, result
  end

  def test_record_spend_with_string_provider
    @budget.record_spend(3.0, 'anthropic')

    assert_equal 3.0, @budget.spent[:anthropic]
  end

  def test_record_spend_raises_for_invalid_provider
    assert_raises(ArgumentError) do
      @budget.record_spend(3.0, :invalid)
    end
  end

  # Total spent tests
  def test_total_spent_sums_all_providers
    @budget.record_spend(3.0, :anthropic)
    @budget.record_spend(2.0, :openai)
    @budget.record_spend(1.0, :google)

    assert_equal 6.0, @budget.total_spent
  end

  def test_total_spent_returns_zero_initially
    assert_equal 0.0, @budget.total_spent
  end

  # Total limit tests
  def test_total_limit_sums_all_limits
    assert_equal 17.0, @budget.total_limit
  end

  def test_total_limit_returns_infinity_when_no_limits
    budget = OrchestraAI::Costs::Budget.new

    assert_equal Float::INFINITY, budget.total_limit
  end

  def test_total_limit_ignores_nil_limits
    budget = OrchestraAI::Costs::Budget.new(limits: { anthropic: 10.0 })

    assert_equal 10.0, budget.total_limit
  end

  # Total remaining tests
  def test_total_remaining
    @budget.record_spend(3.0, :anthropic)

    assert_equal 14.0, @budget.total_remaining
  end

  def test_total_remaining_returns_zero_not_negative
    @budget.record_spend(20.0, :anthropic)

    assert_equal 0.0, @budget.total_remaining
  end

  # Alert threshold tests
  def test_at_alert_threshold_when_below
    @budget.record_spend(7.0, :anthropic)

    refute @budget.at_alert_threshold?(:anthropic)
  end

  def test_at_alert_threshold_when_at
    @budget.record_spend(8.0, :anthropic) # 80% of 10

    assert @budget.at_alert_threshold?(:anthropic)
  end

  def test_at_alert_threshold_when_above
    @budget.record_spend(9.0, :anthropic)

    assert @budget.at_alert_threshold?(:anthropic)
  end

  def test_at_alert_threshold_with_no_limit
    budget = OrchestraAI::Costs::Budget.new

    refute budget.at_alert_threshold?(:anthropic)
  end

  def test_at_alert_threshold_with_zero_limit
    budget = OrchestraAI::Costs::Budget.new(limits: { anthropic: 0.0 })

    refute budget.at_alert_threshold?(:anthropic)
  end

  # Exceeded tests
  def test_exceeded_when_over_limit
    @budget.record_spend(11.0, :anthropic)

    assert @budget.exceeded?(:anthropic)
  end

  def test_exceeded_when_under_limit
    @budget.record_spend(9.0, :anthropic)

    refute @budget.exceeded?(:anthropic)
  end

  def test_exceeded_when_at_limit
    @budget.record_spend(10.0, :anthropic)

    refute @budget.exceeded?(:anthropic)
  end

  def test_exceeded_with_no_limit
    budget = OrchestraAI::Costs::Budget.new

    refute budget.exceeded?(:anthropic)
  end

  def test_exceeded_any_provider
    refute @budget.exceeded?

    @budget.record_spend(11.0, :anthropic)
    assert @budget.exceeded?
  end

  # Reset tests
  def test_reset_specific_provider
    @budget.record_spend(5.0, :anthropic)
    @budget.record_spend(3.0, :openai)

    @budget.reset(:anthropic)

    assert_equal 0.0, @budget.spent[:anthropic]
    assert_equal 3.0, @budget.spent[:openai]
  end

  def test_reset_all_providers
    @budget.record_spend(5.0, :anthropic)
    @budget.record_spend(3.0, :openai)

    @budget.reset

    assert_equal 0.0, @budget.spent[:anthropic]
    assert_equal 0.0, @budget.spent[:openai]
  end

  def test_reset_raises_for_invalid_provider
    assert_raises(ArgumentError) do
      @budget.reset(:invalid)
    end
  end

  # Set limit tests
  def test_set_limit_updates_limit
    @budget.set_limit(:anthropic, 20.0)

    assert_equal 20.0, @budget.limits[:anthropic]
  end

  def test_set_limit_accepts_nil
    @budget.set_limit(:anthropic, nil)

    assert_nil @budget.limits[:anthropic]
  end

  def test_set_limit_converts_to_float
    @budget.set_limit(:anthropic, 15)

    assert_equal 15.0, @budget.limits[:anthropic]
  end

  def test_set_limit_with_string_provider
    @budget.set_limit('anthropic', 20.0)

    assert_equal 20.0, @budget.limits[:anthropic]
  end

  def test_set_limit_raises_for_invalid_provider
    assert_raises(ArgumentError) do
      @budget.set_limit(:invalid, 10.0)
    end
  end

  # To hash tests
  def test_to_h_returns_complete_state
    @budget.record_spend(3.0, :anthropic)

    hash = @budget.to_h

    assert_equal({ anthropic: 10.0, openai: 5.0, google: 2.0 }, hash[:limits])
    assert_equal 3.0, hash[:spent][:anthropic]
    assert_equal 7.0, hash[:remaining][:anthropic]
    assert_equal 0.8, hash[:alert_threshold]
    refute hash[:exceeded]
  end

  # Status summary tests
  def test_status_summary_returns_all_providers
    summary = @budget.status_summary

    assert_includes summary.keys, :anthropic
    assert_includes summary.keys, :openai
    assert_includes summary.keys, :google
  end

  def test_status_summary_ok_status
    summary = @budget.status_summary

    assert_equal :ok, summary[:anthropic][:status]
  end

  def test_status_summary_warning_status
    @budget.record_spend(8.0, :anthropic)

    summary = @budget.status_summary

    assert_equal :warning, summary[:anthropic][:status]
  end

  def test_status_summary_exceeded_status
    @budget.record_spend(11.0, :anthropic)

    summary = @budget.status_summary

    assert_equal :exceeded, summary[:anthropic][:status]
  end

  def test_status_summary_unlimited_status
    budget = OrchestraAI::Costs::Budget.new

    summary = budget.status_summary

    assert_equal :unlimited, summary[:anthropic][:status]
  end

  def test_status_summary_includes_amounts
    @budget.record_spend(3.0, :anthropic)

    summary = @budget.status_summary

    assert_equal 10.0, summary[:anthropic][:limit]
    assert_equal 3.0, summary[:anthropic][:spent]
    assert_equal 7.0, summary[:anthropic][:remaining]
  end

  # Alert firing tests
  def test_alert_fires_when_threshold_reached
    output = capture_io do
      @budget.record_spend(8.0, :anthropic)
    end

    assert_includes output.last, 'Budget alert'
    assert_includes output.last, 'anthropic'
    assert_includes output.last, '80%'
  end

  def test_alert_fires_only_once
    output = capture_io do
      @budget.record_spend(8.0, :anthropic)
      @budget.record_spend(1.0, :anthropic)
    end

    # Should only fire once
    assert_equal 1, output.last.scan('Budget alert').count
  end

  def test_alert_resets_on_budget_reset
    capture_io { @budget.record_spend(8.0, :anthropic) }
    @budget.reset(:anthropic)

    output = capture_io { @budget.record_spend(8.0, :anthropic) }

    assert_includes output.last, 'Budget alert'
  end

  # Providers constant tests
  def test_providers_constant
    assert_equal %i[anthropic openai google], OrchestraAI::Costs::Budget::PROVIDERS
  end
end
