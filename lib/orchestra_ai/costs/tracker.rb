# frozen_string_literal: true

module OrchestraAI
  module Costs
    # Tracks costs across a session and provides savings reports
    class Tracker
      PREMIUM_MODEL = 'claude-opus-4.6'

      attr_reader :results, :budget

      def initialize(budget: nil)
        @budget = budget
        @results = []
        @estimator = Estimator.new
      end

      def record(result)
        return unless result.is_a?(Tasks::Result) && result.success?

        @results << result

        if @budget && result.cost && result.model
          provider = @estimator.provider_for_model(result.model)
          # Map gemini to google for budget tracking
          budget_provider = provider == :gemini ? :google : provider
          @budget.record_spend(result.cost[:total], budget_provider) if budget_provider != :unknown
        end

        result
      end

      def record_all(results)
        Array(results).each { |r| record(r) }
      end

      def total_cost
        @results.sum { |r| r.cost&.dig(:total) || 0.0 }
      end

      def cost_breakdown
        {
          input: @results.sum { |r| r.cost&.dig(:input) || 0.0 },
          output: @results.sum { |r| r.cost&.dig(:output) || 0.0 },
          total: total_cost
        }
      end

      def cost_by_provider
        breakdown = Hash.new { |h, k| h[k] = { input: 0.0, output: 0.0, total: 0.0 } }

        @results.each do |result|
          next unless result.cost && result.model

          provider = @estimator.provider_for_model(result.model)
          breakdown[provider][:input] += result.cost[:input] || 0.0
          breakdown[provider][:output] += result.cost[:output] || 0.0
          breakdown[provider][:total] += result.cost[:total] || 0.0
        end

        breakdown.to_h
      end

      def cost_by_model
        breakdown = Hash.new { |h, k| h[k] = { input: 0.0, output: 0.0, total: 0.0, count: 0 } }

        @results.each do |result|
          next unless result.cost && result.model

          model = result.model
          breakdown[model][:input] += result.cost[:input] || 0.0
          breakdown[model][:output] += result.cost[:output] || 0.0
          breakdown[model][:total] += result.cost[:total] || 0.0
          breakdown[model][:count] += 1
        end

        breakdown.to_h
      end

      def cost_by_agent
        breakdown = Hash.new { |h, k| h[k] = { input: 0.0, output: 0.0, total: 0.0, count: 0 } }

        @results.each do |result|
          next unless result.cost

          agent = result.agent || :unknown
          breakdown[agent][:input] += result.cost[:input] || 0.0
          breakdown[agent][:output] += result.cost[:output] || 0.0
          breakdown[agent][:total] += result.cost[:total] || 0.0
          breakdown[agent][:count] += 1
        end

        breakdown.to_h
      end

      def premium_equivalent_cost
        total = 0.0
        pricing = Providers::RubyLLMProvider::MODELS[PREMIUM_MODEL]

        @results.each do |result|
          next unless result.usage

          input_tokens = result.usage[:input_tokens] || 0
          output_tokens = result.usage[:output_tokens] || 0

          input_cost = (input_tokens / 1_000_000.0) * pricing[:input]
          output_cost = (output_tokens / 1_000_000.0) * pricing[:output]

          total += input_cost + output_cost
        end

        total
      end

      def savings_report
        actual = total_cost
        premium = premium_equivalent_cost

        savings_amount = premium - actual
        savings_percentage = premium.positive? ? (savings_amount / premium) * 100 : 0.0

        {
          actual_cost: actual,
          premium_equivalent: premium,
          savings_amount: savings_amount,
          savings_percentage: savings_percentage,
          tasks_completed: @results.count,
          cost_breakdown: cost_breakdown,
          by_provider: cost_by_provider,
          by_model: cost_by_model,
          by_agent: cost_by_agent,
          budget_status: @budget&.status_summary
        }
      end

      def savings_summary
        report = savings_report

        lines = []
        lines << '═══════════════════════════════════════════════════════'
        lines << '                    COST SAVINGS REPORT                '
        lines << '═══════════════════════════════════════════════════════'
        lines << ''
        lines << "Tasks Completed: #{report[:tasks_completed]}"
        lines << ''
        lines << '───────────────────────────────────────────────────────'
        lines << '                      COST SUMMARY                     '
        lines << '───────────────────────────────────────────────────────'
        lines << "Actual Cost:              $#{'%.6f' % report[:actual_cost]}"
        lines << "Premium Equivalent:       $#{'%.6f' % report[:premium_equivalent]}"
        lines << "                          (using #{PREMIUM_MODEL} for all)"
        lines << ''
        lines << "SAVINGS:                  $#{'%.6f' % report[:savings_amount]}"
        lines << "                          (#{'%.1f' % report[:savings_percentage]}% reduction)"

        if report[:by_provider].any?
          lines << ''
          lines << '───────────────────────────────────────────────────────'
          lines << '                    BY PROVIDER                       '
          lines << '───────────────────────────────────────────────────────'
          report[:by_provider].each do |provider, costs|
            lines << "#{provider.to_s.capitalize.ljust(25)} $#{'%.6f' % costs[:total]}"
          end
        end

        if report[:by_model].any?
          lines << ''
          lines << '───────────────────────────────────────────────────────'
          lines << '                     BY MODEL                         '
          lines << '───────────────────────────────────────────────────────'
          report[:by_model].each do |model, data|
            lines << "#{model.ljust(25)} $#{'%.6f' % data[:total]} (#{data[:count]} calls)"
          end
        end

        if report[:budget_status]
          lines << ''
          lines << '───────────────────────────────────────────────────────'
          lines << '                   BUDGET STATUS                      '
          lines << '───────────────────────────────────────────────────────'
          report[:budget_status].each do |provider, status|
            status_icon = case status[:status]
                          when :ok then '✓'
                          when :warning then '⚠'
                          when :exceeded then '✗'
                          when :unlimited then '∞'
                          end
            limit_str = status[:limit] ? "$#{'%.2f' % status[:limit]}" : 'unlimited'
            lines << "#{status_icon} #{provider.to_s.capitalize.ljust(12)} Spent: $#{'%.4f' % status[:spent]} / #{limit_str}"
          end
        end

        lines << ''
        lines << '═══════════════════════════════════════════════════════'

        lines.join("\n")
      end

      def reset
        @results = []
      end
    end
  end
end
