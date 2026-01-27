# frozen_string_literal: true

module OrchestraAI
  module Tasks
    class Assigner
      class << self
        # Assign appropriate model to a task based on difficulty and agent role
        # @param task [Tasks::Definition] The task to assign
        # @param agent [Symbol] The agent role (:architect, :implementer, :reviewer)
        # @return [String] The assigned model name
        def assign(task, agent:)
          difficulty = task.difficulty || DifficultyScorer.score(task)
          tier = DifficultyScorer.classify(task)

          model = select_model(agent, tier)

          # Verify model is available, fallback if not
          model = find_fallback(agent, tier) unless Providers::Registry.model_available?(model)

          task.assigned_model = model
          task.assigned_agent = agent
          task.difficulty = difficulty

          model
        end

        # Assign models to multiple tasks, optimizing for cost
        # @param tasks [Array<Tasks::Definition>] Tasks to assign
        # @param agent [Symbol] The agent role
        # @return [Hash] Map of task_id => model
        def assign_batch(tasks, agent:)
          tasks.each_with_object({}) do |task, assignments|
            assignments[task.id] = assign(task, agent: agent)
          end
        end

        # Estimate cost for executing a task
        # @param task [Tasks::Definition] The task
        # @param model [String] The model to use
        # @return [Hash] Estimated costs { input: Float, output: Float, total: Float }
        def estimate_cost(task, model: nil)
          model ||= task.assigned_model
          return nil unless model

          info = Providers::RubyLLMProvider::MODELS[model]
          return nil unless info

          # Rough token estimation: 4 chars per token
          input_tokens = (task.description.length / 4.0).ceil
          input_tokens += task.context.sum { |c| c.to_s.length / 4 } if task.context.any?

          # Estimate output as 2x input for complex tasks, 1x for simple
          difficulty = task.difficulty || 0.5
          output_multiplier = 1 + difficulty
          output_tokens = (input_tokens * output_multiplier).ceil

          input_cost = (input_tokens / 1_000_000.0) * info[:input]
          output_cost = (output_tokens / 1_000_000.0) * info[:output]

          {
            input_tokens: input_tokens,
            output_tokens: output_tokens,
            input_cost: input_cost,
            output_cost: output_cost,
            total_cost: input_cost + output_cost,
            model: model
          }
        end

        private

        def select_model(agent, tier)
          config = OrchestraAI.configuration
          model_config = config.models.send(agent)
          model_config.send(tier)
        end

        def find_fallback(agent, tier)
          tiers = %i[simple moderate complex]
          current_index = tiers.index(tier)

          # Try lower tiers first, then higher
          search_order = tiers[0..current_index].reverse + tiers[(current_index + 1)..]

          search_order.each do |fallback_tier|
            model = select_model(agent, fallback_tier)
            return model if Providers::Registry.model_available?(model)
          end

          raise AgentNotConfiguredError, "No available model for #{agent} agent"
        end
      end
    end
  end
end
