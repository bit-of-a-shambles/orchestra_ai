# frozen_string_literal: true

module OrchestraAI
  module Costs
    # Estimates execution costs with confidence intervals and safety buffers
    class Estimator
      # Safety multiplier for budget enforcement (accounts for estimation variance)
      SAFETY_MULTIPLIER = 1.3

      # Default token estimates per agent role
      DEFAULT_TOKEN_ESTIMATES = {
        architect: { input: 1500, output: 800 },
        implementer: { input: 2000, output: 1500 },
        reviewer: { input: 1800, output: 600 }
      }.freeze

      # Variance factors for confidence intervals
      VARIANCE_LOW = 0.8
      VARIANCE_HIGH = 1.5

      def initialize
        @pricing = Providers::RubyLLMProvider::MODELS
      end

      def estimate_task(task, model:, role: :implementer)
        tokens = estimate_tokens(task, role)
        calculate_cost_estimate(model, tokens, role)
      end

      def estimate_pipeline(task, stages:, models:)
        stage_estimates = stages.map.with_index do |stage, idx|
          model = models[idx] || models.last
          estimate_task(task, model: model, role: stage)
        end

        aggregate_estimates(stage_estimates)
      end

      def estimate_with_difficulty(task)
        difficulty = Tasks::DifficultyScorer.score(task)
        classification = Tasks::DifficultyScorer.classify(task)

        config = OrchestraAI.configuration
        stages = stages_for_difficulty(classification)

        models = stages.map do |stage|
          role_config = config.models.send(stage)
          role_config.send(classification)
        end

        estimate = estimate_pipeline(task, stages: stages, models: models)
        estimate.merge(
          difficulty: difficulty,
          classification: classification,
          stage_details: estimate[:stages], # Preserve detailed stage estimates
          stages: stages,                    # Role symbols for convenience
          models: models
        )
      end

      def cost_for_tokens(model, input_tokens:, output_tokens:)
        model_info = @pricing[model]
        return nil unless model_info

        input_cost = (input_tokens / 1_000_000.0) * model_info[:input]
        output_cost = (output_tokens / 1_000_000.0) * model_info[:output]

        {
          input: input_cost,
          output: output_cost,
          total: input_cost + output_cost
        }
      end

      def provider_for_model(model)
        model_info = @pricing[model]
        model_info&.fetch(:provider, :unknown) || :unknown
      end

      private

      def estimate_tokens(task, role)
        base = DEFAULT_TOKEN_ESTIMATES[role] || DEFAULT_TOKEN_ESTIMATES[:implementer]

        description_length = task.description&.length || 0
        context_length = Array(task.context).join.length

        # Scale input tokens based on task complexity
        input_multiplier = 1.0 + (description_length / 500.0) + (context_length / 1000.0)
        output_multiplier = 1.0 + (description_length / 1000.0)

        {
          input: (base[:input] * input_multiplier).to_i,
          output: (base[:output] * output_multiplier).to_i
        }
      end

      def calculate_cost_estimate(model, tokens, role)
        model_info = @pricing[model]
        return nil_estimate(model, role) unless model_info

        base_cost = cost_for_tokens(model, input_tokens: tokens[:input], output_tokens: tokens[:output])

        {
          model: model,
          role: role,
          provider: model_info[:provider],
          tokens: tokens,
          estimated: base_cost,
          safe: apply_safety_multiplier(base_cost),
          confidence: {
            low: apply_variance(base_cost, VARIANCE_LOW),
            high: apply_variance(base_cost, VARIANCE_HIGH)
          }
        }
      end

      def nil_estimate(model, role)
        {
          model: model,
          role: role,
          provider: :unknown,
          tokens: { input: 0, output: 0 },
          estimated: { input: 0.0, output: 0.0, total: 0.0 },
          safe: { input: 0.0, output: 0.0, total: 0.0 },
          confidence: {
            low: { input: 0.0, output: 0.0, total: 0.0 },
            high: { input: 0.0, output: 0.0, total: 0.0 }
          }
        }
      end

      def apply_safety_multiplier(cost)
        {
          input: cost[:input] * SAFETY_MULTIPLIER,
          output: cost[:output] * SAFETY_MULTIPLIER,
          total: cost[:total] * SAFETY_MULTIPLIER
        }
      end

      def apply_variance(cost, factor)
        {
          input: cost[:input] * factor,
          output: cost[:output] * factor,
          total: cost[:total] * factor
        }
      end

      def aggregate_estimates(estimates)
        totals = { input: 0.0, output: 0.0, total: 0.0 }
        safe_totals = { input: 0.0, output: 0.0, total: 0.0 }
        confidence_low = { input: 0.0, output: 0.0, total: 0.0 }
        confidence_high = { input: 0.0, output: 0.0, total: 0.0 }
        by_provider = Hash.new { |h, k| h[k] = { input: 0.0, output: 0.0, total: 0.0 } }

        estimates.each do |est|
          %i[input output total].each do |key|
            totals[key] += est[:estimated][key]
            safe_totals[key] += est[:safe][key]
            confidence_low[key] += est[:confidence][:low][key]
            confidence_high[key] += est[:confidence][:high][key]
          end

          provider = est[:provider]
          %i[input output total].each do |key|
            by_provider[provider][key] += est[:safe][key]
          end
        end

        {
          stages: estimates,
          estimated: totals,
          safe: safe_totals,
          confidence: { low: confidence_low, high: confidence_high },
          by_provider: by_provider.to_h
        }
      end

      def stages_for_difficulty(classification)
        case classification
        when :simple
          [:implementer]
        when :moderate
          %i[implementer reviewer]
        when :complex
          %i[architect implementer reviewer]
        else
          [:implementer]
        end
      end
    end
  end
end
