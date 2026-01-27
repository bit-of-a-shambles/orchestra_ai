# frozen_string_literal: true

require 'test_helper'

class TrackerTest < Minitest::Test
  def setup
    @budget = OrchestraAI::Costs::Budget.new(
      limits: { anthropic: 10.0, openai: 5.0, google: 2.0 }
    )
    @tracker = OrchestraAI::Costs::Tracker.new(budget: @budget)
    @task = OrchestraAI::Tasks::Definition.new(description: 'Test task')
  end

  # Initialization tests
  def test_initialize_with_budget
    assert_equal @budget, @tracker.budget
  end

  def test_initialize_without_budget
    tracker = OrchestraAI::Costs::Tracker.new

    assert_nil tracker.budget
  end

  def test_initialize_with_empty_results
    assert_equal [], @tracker.results
  end

  # Premium model constant
  def test_premium_model_constant
    assert_equal 'claude-opus-4.5', OrchestraAI::Costs::Tracker::PREMIUM_MODEL
  end

  # Record tests
  def test_record_adds_successful_result
    result = create_result(content: 'Test', model: 'gemini-2.5-flash')

    @tracker.record(result)

    assert_equal 1, @tracker.results.length
  end

  def test_record_ignores_failed_result
    result = create_result(content: nil, success: false, error: StandardError.new('Failed'))

    @tracker.record(result)

    assert_equal 0, @tracker.results.length
  end

  def test_record_ignores_non_result_objects
    @tracker.record('not a result')

    assert_equal 0, @tracker.results.length
  end

  def test_record_updates_budget
    result = create_result(
      content: 'Test',
      model: 'gemini-2.5-flash',
      usage: { input_tokens: 1000, output_tokens: 500 }
    )

    @tracker.record(result)

    assert @budget.spent[:google].positive?
  end

  def test_record_returns_result
    result = create_result(content: 'Test', model: 'gemini-2.5-flash')

    returned = @tracker.record(result)

    assert_equal result, returned
  end

  # Record all tests
  def test_record_all_adds_multiple_results
    results = [
      create_result(content: 'Test 1', model: 'gemini-2.5-flash'),
      create_result(content: 'Test 2', model: 'gpt-5-mini')
    ]

    @tracker.record_all(results)

    assert_equal 2, @tracker.results.length
  end

  def test_record_all_handles_single_result
    result = create_result(content: 'Test', model: 'gemini-2.5-flash')

    @tracker.record_all(result)

    assert_equal 1, @tracker.results.length
  end

  # Total cost tests
  def test_total_cost_sums_all_results
    @tracker.record(create_result(content: 'Test 1', model: 'gemini-2.5-flash',
                                  usage: { input_tokens: 1000, output_tokens: 500 }))
    @tracker.record(create_result(content: 'Test 2', model: 'gpt-5-mini',
                                  usage: { input_tokens: 2000, output_tokens: 1000 }))

    assert @tracker.total_cost.positive?
  end

  def test_total_cost_returns_zero_when_no_results
    assert_equal 0.0, @tracker.total_cost
  end

  def test_total_cost_handles_results_without_cost
    result = OrchestraAI::Tasks::Result.new(
      content: 'Test',
      task: @task,
      agent: :implementer
    )
    @tracker.record(result)

    assert_equal 0.0, @tracker.total_cost
  end

  # Cost breakdown tests
  def test_cost_breakdown_returns_hash
    breakdown = @tracker.cost_breakdown

    assert_includes breakdown.keys, :input
    assert_includes breakdown.keys, :output
    assert_includes breakdown.keys, :total
  end

  def test_cost_breakdown_calculates_correctly
    @tracker.record(create_result(content: 'Test', model: 'gemini-2.5-flash',
                                  usage: { input_tokens: 1000, output_tokens: 500 }))

    breakdown = @tracker.cost_breakdown

    assert breakdown[:input].positive?
    assert breakdown[:output].positive?
    assert_equal breakdown[:input] + breakdown[:output], breakdown[:total]
  end

  # Cost by provider tests
  def test_cost_by_provider_returns_hash
    @tracker.record(create_result(content: 'Test', model: 'gemini-2.5-flash',
                                  usage: { input_tokens: 1000, output_tokens: 500 }))

    by_provider = @tracker.cost_by_provider

    assert_instance_of Hash, by_provider
  end

  def test_cost_by_provider_groups_correctly
    @tracker.record(create_result(content: 'Test 1', model: 'gemini-2.5-flash',
                                  usage: { input_tokens: 1000, output_tokens: 500 }))
    @tracker.record(create_result(content: 'Test 2', model: 'gpt-5-mini',
                                  usage: { input_tokens: 2000, output_tokens: 1000 }))

    by_provider = @tracker.cost_by_provider

    assert by_provider[:gemini][:total].positive?
    assert by_provider[:openai][:total].positive?
  end

  # Cost by model tests
  def test_cost_by_model_returns_hash
    @tracker.record(create_result(content: 'Test', model: 'gemini-2.5-flash',
                                  usage: { input_tokens: 1000, output_tokens: 500 }))

    by_model = @tracker.cost_by_model

    assert_instance_of Hash, by_model
  end

  def test_cost_by_model_groups_correctly
    @tracker.record(create_result(content: 'Test 1', model: 'gemini-2.5-flash',
                                  usage: { input_tokens: 1000, output_tokens: 500 }))
    @tracker.record(create_result(content: 'Test 2', model: 'gemini-2.5-flash',
                                  usage: { input_tokens: 1000, output_tokens: 500 }))

    by_model = @tracker.cost_by_model

    assert_equal 2, by_model['gemini-2.5-flash'][:count]
  end

  def test_cost_by_model_includes_count
    @tracker.record(create_result(content: 'Test', model: 'gemini-2.5-flash',
                                  usage: { input_tokens: 1000, output_tokens: 500 }))

    by_model = @tracker.cost_by_model

    assert_includes by_model['gemini-2.5-flash'].keys, :count
  end

  # Cost by agent tests
  def test_cost_by_agent_returns_hash
    @tracker.record(create_result(content: 'Test', model: 'gemini-2.5-flash', agent: :implementer,
                                  usage: { input_tokens: 1000, output_tokens: 500 }))

    by_agent = @tracker.cost_by_agent

    assert_instance_of Hash, by_agent
  end

  def test_cost_by_agent_groups_correctly
    @tracker.record(create_result(content: 'Test 1', model: 'gemini-2.5-flash', agent: :implementer,
                                  usage: { input_tokens: 1000, output_tokens: 500 }))
    @tracker.record(create_result(content: 'Test 2', model: 'gpt-5-mini', agent: :reviewer,
                                  usage: { input_tokens: 2000, output_tokens: 1000 }))

    by_agent = @tracker.cost_by_agent

    assert by_agent[:implementer][:total].positive?
    assert by_agent[:reviewer][:total].positive?
  end

  def test_cost_by_agent_includes_count
    @tracker.record(create_result(content: 'Test', model: 'gemini-2.5-flash', agent: :implementer,
                                  usage: { input_tokens: 1000, output_tokens: 500 }))

    by_agent = @tracker.cost_by_agent

    assert_includes by_agent[:implementer].keys, :count
  end

  # Premium equivalent cost tests
  def test_premium_equivalent_cost_calculates_correctly
    @tracker.record(create_result(content: 'Test', model: 'gemini-2.5-flash',
                                  usage: { input_tokens: 1000, output_tokens: 500 }))

    premium_cost = @tracker.premium_equivalent_cost

    # Should be higher than actual cost (claude-opus-4.5 is $5/$25 per 1M vs gemini at $0.10/$0.40)
    assert premium_cost > @tracker.total_cost
  end

  def test_premium_equivalent_cost_returns_zero_when_no_results
    assert_equal 0.0, @tracker.premium_equivalent_cost
  end

  # Savings report tests
  def test_savings_report_returns_hash
    report = @tracker.savings_report

    assert_instance_of Hash, report
  end

  def test_savings_report_includes_actual_cost
    assert_includes @tracker.savings_report.keys, :actual_cost
  end

  def test_savings_report_includes_premium_equivalent
    assert_includes @tracker.savings_report.keys, :premium_equivalent
  end

  def test_savings_report_includes_savings_amount
    assert_includes @tracker.savings_report.keys, :savings_amount
  end

  def test_savings_report_includes_savings_percentage
    assert_includes @tracker.savings_report.keys, :savings_percentage
  end

  def test_savings_report_includes_tasks_completed
    @tracker.record(create_result(content: 'Test', model: 'gemini-2.5-flash',
                                  usage: { input_tokens: 1000, output_tokens: 500 }))

    report = @tracker.savings_report

    assert_equal 1, report[:tasks_completed]
  end

  def test_savings_report_includes_breakdowns
    report = @tracker.savings_report

    assert_includes report.keys, :cost_breakdown
    assert_includes report.keys, :by_provider
    assert_includes report.keys, :by_model
    assert_includes report.keys, :by_agent
  end

  def test_savings_report_includes_budget_status
    report = @tracker.savings_report

    assert_includes report.keys, :budget_status
  end

  def test_savings_report_budget_status_nil_without_budget
    tracker = OrchestraAI::Costs::Tracker.new

    report = tracker.savings_report

    assert_nil report[:budget_status]
  end

  def test_savings_report_calculates_savings_correctly
    @tracker.record(create_result(content: 'Test', model: 'gemini-2.5-flash',
                                  usage: { input_tokens: 1000, output_tokens: 500 }))

    report = @tracker.savings_report

    expected_savings = report[:premium_equivalent] - report[:actual_cost]
    assert_in_delta expected_savings, report[:savings_amount], 0.0001
  end

  def test_savings_report_calculates_percentage_correctly
    @tracker.record(create_result(content: 'Test', model: 'gemini-2.5-flash',
                                  usage: { input_tokens: 1000, output_tokens: 500 }))

    report = @tracker.savings_report

    expected_percentage = (report[:savings_amount] / report[:premium_equivalent]) * 100
    assert_in_delta expected_percentage, report[:savings_percentage], 0.01
  end

  def test_savings_report_percentage_zero_when_no_premium
    report = @tracker.savings_report

    assert_equal 0.0, report[:savings_percentage]
  end

  # Savings summary tests
  def test_savings_summary_returns_string
    assert_instance_of String, @tracker.savings_summary
  end

  def test_savings_summary_includes_header
    assert_includes @tracker.savings_summary, 'COST SAVINGS REPORT'
  end

  def test_savings_summary_includes_tasks_completed
    @tracker.record(create_result(content: 'Test', model: 'gemini-2.5-flash',
                                  usage: { input_tokens: 1000, output_tokens: 500 }))

    assert_includes @tracker.savings_summary, 'Tasks Completed: 1'
  end

  def test_savings_summary_includes_actual_cost
    assert_includes @tracker.savings_summary, 'Actual Cost'
  end

  def test_savings_summary_includes_premium_equivalent
    assert_includes @tracker.savings_summary, 'Premium Equivalent'
    assert_includes @tracker.savings_summary, 'claude-opus-4.5'
  end

  def test_savings_summary_includes_savings
    assert_includes @tracker.savings_summary, 'SAVINGS'
  end

  def test_savings_summary_includes_provider_breakdown
    @tracker.record(create_result(content: 'Test', model: 'gemini-2.5-flash',
                                  usage: { input_tokens: 1000, output_tokens: 500 }))

    summary = @tracker.savings_summary

    assert_includes summary, 'BY PROVIDER'
  end

  def test_savings_summary_includes_model_breakdown
    @tracker.record(create_result(content: 'Test', model: 'gemini-2.5-flash',
                                  usage: { input_tokens: 1000, output_tokens: 500 }))

    summary = @tracker.savings_summary

    assert_includes summary, 'BY MODEL'
    assert_includes summary, 'gemini-2.5-flash'
  end

  def test_savings_summary_includes_budget_status
    @tracker.record(create_result(content: 'Test', model: 'gemini-2.5-flash',
                                  usage: { input_tokens: 1000, output_tokens: 500 }))

    summary = @tracker.savings_summary

    assert_includes summary, 'BUDGET STATUS'
  end

  # Reset tests
  def test_reset_clears_results
    @tracker.record(create_result(content: 'Test', model: 'gemini-2.5-flash',
                                  usage: { input_tokens: 1000, output_tokens: 500 }))

    @tracker.reset

    assert_equal [], @tracker.results
  end

  private

  def create_result(content:, model: 'gemini-2.5-flash', agent: :implementer, usage: {}, success: true, error: nil)
    OrchestraAI::Tasks::Result.new(
      content: content,
      task: @task,
      agent: agent,
      model: model,
      usage: usage,
      success: success,
      error: error
    )
  end
end
