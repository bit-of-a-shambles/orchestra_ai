# frozen_string_literal: true

module OrchestraAI
  module Costs
    # Plans task execution within budget constraints
    class Planner
      SUFFICIENCY_LEVELS = %i[sufficient partial insufficient].freeze

      # Alternative models ranked by cost (cheapest first) per provider
      ALTERNATIVES = {
        google: %w[gemini-2.5-flash-lite gemini-2.5-flash gemini-3-flash gemini-2.5-pro gemini-3-pro],
        openai: %w[gpt-5-nano gpt-5-mini gpt-4.1 o4-mini gpt-5.2-codex],
        anthropic: %w[claude-haiku-4.5 claude-sonnet-4.5 claude-opus-4.5]
      }.freeze

      attr_reader :budget, :estimator

      def initialize(budget:)
        @budget = budget
        @estimator = Estimator.new
      end

      def plan(task)
        estimate = @estimator.estimate_with_difficulty(task)
        sufficiency = assess_sufficiency(estimate)

        case sufficiency
        when :sufficient
          build_plan(task, estimate, sufficiency, estimate[:models])
        when :partial, :insufficient
          alternatives = find_affordable_alternatives(task, estimate)
          build_plan(task, estimate, sufficiency, alternatives[:models], alternatives)
        end
      end

      def can_execute?(task)
        execution_plan = plan(task)
        execution_plan.sufficiency != :insufficient
      end

      def recommend_models(task, max_cost: nil)
        estimate = @estimator.estimate_with_difficulty(task)
        stage_roles = estimate[:stages] # This is array of role symbols like [:implementer, :reviewer]

        recommendations = stage_roles.map do |role|
          find_best_model_for_budget(role, max_cost)
        end

        {
          stages: stage_roles,
          recommended_models: recommendations,
          estimated_cost: recalculate_cost(task, stage_roles, recommendations)
        }
      end

      private

      def assess_sufficiency(estimate)
        by_provider = estimate[:by_provider]

        all_affordable = by_provider.all? do |provider, costs|
          # Map gemini to google for budget checking
          budget_provider = provider == :gemini ? :google : provider
          @budget.can_afford?(costs[:total], budget_provider)
        end

        return :sufficient if all_affordable

        any_affordable = by_provider.any? do |provider, costs|
          budget_provider = provider == :gemini ? :google : provider
          @budget.remaining(budget_provider) > 0
        end

        any_affordable ? :partial : :insufficient
      end

      def find_affordable_alternatives(task, original_estimate)
        stage_roles = original_estimate[:stages] # Role symbols like [:implementer, :reviewer]
        stage_details = original_estimate[:stage_details] # Detailed estimates with model, provider info
        alternative_models = []
        total_by_provider = Hash.new(0.0)

        stage_roles.each_with_index do |role, idx|
          original_model = stage_details[idx][:model] if stage_details && stage_details[idx]

          # Try to find an affordable model
          model = find_affordable_model(role, total_by_provider)

          if model
            alternative_models << model
            stage_estimate = @estimator.estimate_task(task, model: model, role: role)
            provider = stage_estimate[:provider]
            # Map gemini to google for budget tracking
            budget_provider = provider == :gemini ? :google : provider
            total_by_provider[budget_provider] += stage_estimate[:safe][:total]
          else
            alternative_models << (original_model || original_estimate[:models][idx])
          end
        end

        new_estimate = @estimator.estimate_pipeline(
          task,
          stages: stage_roles,
          models: alternative_models
        )

        {
          models: alternative_models,
          estimate: new_estimate,
          savings: calculate_savings(original_estimate, new_estimate)
        }
      end

      def find_affordable_model(role, current_spend)
        # Try each provider's models from cheapest to most expensive
        ALTERNATIVES.each do |provider, models|
          models.each do |model|
            estimate = @estimator.estimate_task(
              Tasks::Definition.new(description: 'test'),
              model: model,
              role: role
            )

            projected_total = current_spend[provider] + estimate[:safe][:total]

            return model if @budget.can_afford?(projected_total, provider)
          end
        end

        nil
      end

      def find_best_model_for_budget(role, max_cost)
        return default_model_for_role(role) unless max_cost

        ALTERNATIVES.values.flatten.reverse.each do |model|
          estimate = @estimator.estimate_task(
            Tasks::Definition.new(description: 'test'),
            model: model,
            role: role
          )

          return model if estimate[:safe][:total] <= max_cost
        end

        # Return cheapest if nothing fits
        'gemini-2.5-flash-lite'
      end

      def default_model_for_role(role)
        config = OrchestraAI.configuration
        role_config = config.models.send(role)
        role_config.moderate
      end

      def calculate_savings(original, alternative)
        {
          input: original[:safe][:input] - alternative[:safe][:input],
          output: original[:safe][:output] - alternative[:safe][:output],
          total: original[:safe][:total] - alternative[:safe][:total]
        }
      end

      def recalculate_cost(task, stages, models)
        estimate = @estimator.estimate_pipeline(task, stages: stages, models: models)
        estimate[:safe]
      end

      def build_plan(task, estimate, sufficiency, models, alternatives = nil)
        plan = {
          task: task,
          sufficiency: sufficiency,
          difficulty: estimate[:difficulty],
          classification: estimate[:classification],
          stages: estimate[:stages], # Already role symbols like [:implementer, :reviewer]
          recommended_models: models,
          estimated_cost: estimate[:safe],
          confidence: estimate[:confidence],
          by_provider: estimate[:by_provider],
          budget_status: @budget.status_summary,
          warnings: build_warnings(estimate, sufficiency)
        }

        if alternatives
          plan[:alternatives] = {
            models: alternatives[:models],
            estimated_cost: alternatives[:estimate][:safe],
            savings_vs_original: alternatives[:savings]
          }
        end

        plan[:premium_comparison] = calculate_premium_comparison(task)

        ExecutionPlan.new(plan)
      end

      def build_warnings(estimate, sufficiency)
        warnings = []

        if sufficiency == :partial
          warnings << 'Budget partially available. Some stages may use cheaper alternatives.'
        elsif sufficiency == :insufficient
          warnings << 'Insufficient budget across all providers. Task cannot be completed satisfactorily.'
        end

        estimate[:by_provider].each do |provider, costs|
          if @budget.at_alert_threshold?(provider)
            warnings << "#{provider} budget at alert threshold (#{(@budget.alert_threshold * 100).to_i}%)"
          end

          warnings << "#{provider} budget exceeded" if @budget.exceeded?(provider)
        end

        warnings
      end

      def calculate_premium_comparison(task)
        # Estimate cost if using only claude-opus-4.5 (most expensive)
        premium_model = 'claude-opus-4.5'
        stages = %i[architect implementer reviewer]

        premium_estimate = @estimator.estimate_pipeline(
          task,
          stages: stages,
          models: [premium_model] * stages.length
        )

        {
          premium_model: premium_model,
          premium_cost: premium_estimate[:safe],
          premium_stages: stages
        }
      end
    end

    # Represents a planned execution with cost estimates
    class ExecutionPlan
      attr_reader :task, :sufficiency, :difficulty, :classification,
                  :stages, :recommended_models, :estimated_cost, :confidence,
                  :by_provider, :budget_status, :warnings, :alternatives,
                  :premium_comparison

      def initialize(attrs)
        @task = attrs[:task]
        @sufficiency = attrs[:sufficiency]
        @difficulty = attrs[:difficulty]
        @classification = attrs[:classification]
        @stages = attrs[:stages]
        @recommended_models = attrs[:recommended_models]
        @estimated_cost = attrs[:estimated_cost]
        @confidence = attrs[:confidence]
        @by_provider = attrs[:by_provider]
        @budget_status = attrs[:budget_status]
        @warnings = attrs[:warnings] || []
        @alternatives = attrs[:alternatives]
        @premium_comparison = attrs[:premium_comparison]
      end

      def sufficient?
        @sufficiency == :sufficient
      end

      def partial?
        @sufficiency == :partial
      end

      def insufficient?
        @sufficiency == :insufficient
      end

      def executable?
        !insufficient?
      end

      def potential_savings
        return nil unless @premium_comparison

        {
          vs_premium: @premium_comparison[:premium_cost][:total] - @estimated_cost[:total],
          percentage: calculate_savings_percentage
        }
      end

      def to_h
        {
          sufficiency: @sufficiency,
          difficulty: @difficulty,
          classification: @classification,
          stages: @stages,
          recommended_models: @recommended_models,
          estimated_cost: @estimated_cost,
          confidence: @confidence,
          by_provider: @by_provider,
          budget_status: @budget_status,
          warnings: @warnings,
          alternatives: @alternatives,
          premium_comparison: @premium_comparison,
          potential_savings: potential_savings
        }
      end

      def summary
        lines = []
        lines << "Task Classification: #{@classification} (score: #{@difficulty&.round(2)})"
        lines << "Sufficiency: #{@sufficiency.to_s.upcase}"
        lines << ''
        lines << 'Execution Plan:'
        @stages.each_with_index do |stage, i|
          lines << "  #{i + 1}. #{stage} → #{@recommended_models[i]}"
        end
        lines << ''
        lines << "Estimated Cost: $#{'%.4f' % @estimated_cost[:total]}"
        lines << "  - Input:  $#{'%.4f' % @estimated_cost[:input]}"
        lines << "  - Output: $#{'%.4f' % @estimated_cost[:output]}"
        lines << ''
        lines << "Confidence Range: $#{'%.4f' % @confidence[:low][:total]} - $#{'%.4f' % @confidence[:high][:total]}"

        if @warnings.any?
          lines << ''
          lines << 'Warnings:'
          @warnings.each { |w| lines << "  ⚠ #{w}" }
        end

        if potential_savings
          lines << ''
          lines << "Potential Savings vs Premium: $#{'%.4f' % potential_savings[:vs_premium]} (#{'%.1f' % potential_savings[:percentage]}%)"
        end

        lines.join("\n")
      end

      private

      def calculate_savings_percentage
        return 0.0 unless @premium_comparison

        premium = @premium_comparison[:premium_cost][:total]
        return 0.0 if premium.zero?

        ((premium - @estimated_cost[:total]) / premium) * 100
      end
    end
  end
end
