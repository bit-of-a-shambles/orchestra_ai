# frozen_string_literal: true

module OrchestraAI
  module Tasks
    class Result
      attr_reader :content, :task, :agent, :model, :usage, :metadata, :error, :completed_at

      def initialize(content:, task:, agent:, model: nil, usage: nil, metadata: nil, error: nil, success: true)
        @content = content
        @task = task
        @agent = agent
        @model = model
        @usage = usage || {}
        @metadata = metadata || {}
        @error = error
        @success = success && error.nil?
        @completed_at = Time.now.utc
      end

      def success?
        @success
      end

      def failed?
        !success?
      end

      def to_h
        {
          task_id: task.id,
          agent: agent,
          model: model,
          success: success?,
          content: content,
          error: error&.message,
          usage: usage,
          metadata: metadata,
          completed_at: completed_at
        }
      end

      def to_context
        return nil if failed?

        <<~CONTEXT
          Agent: #{agent}
          Model: #{model}
          ---
          #{content}
        CONTEXT
      end

      # Cost calculation based on usage
      def cost
        return nil unless usage[:input_tokens] && usage[:output_tokens] && model

        provider_class = Providers::Registry.for_model(model)
        info = provider_class::MODELS[model]
        return nil unless info

        input_cost = (usage[:input_tokens] / 1_000_000.0) * info[:input]
        output_cost = (usage[:output_tokens] / 1_000_000.0) * info[:output]

        {
          input: input_cost,
          output: output_cost,
          total: input_cost + output_cost
        }
      end

      # Duration in seconds
      def duration
        return nil unless task.created_at && completed_at

        completed_at - task.created_at
      end
    end
  end
end
