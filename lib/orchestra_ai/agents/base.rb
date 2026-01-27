# frozen_string_literal: true

module OrchestraAI
  module Agents
    class Base
      attr_reader :role, :system_prompt

      def initialize(system_prompt: nil)
        @system_prompt = system_prompt || default_system_prompt
      end

      # Execute a task using this agent
      # @param task [Tasks::Definition] The task to execute
      # @param options [Hash] Additional options (temperature, max_tokens, etc.)
      # @return [Tasks::Result] The execution result
      def execute(task, **options)
        provider = get_provider_for_task(task)
        messages = build_messages(task)

        response = provider.complete(messages, **options)

        Tasks::Result.new(
          content: response[:content],
          task: task,
          agent: role,
          model: response[:model],
          usage: response[:usage],
          metadata: {
            provider: response[:provider],
            timestamp: response[:timestamp]
          }
        )
      rescue StandardError => e
        Tasks::Result.new(
          content: nil,
          task: task,
          agent: role,
          error: e,
          success: false
        )
      end

      # Execute with streaming
      def stream(task, **options, &block)
        provider = get_provider_for_task(task)
        messages = build_messages(task)

        response = provider.stream(messages, **options, &block)

        Tasks::Result.new(
          content: response[:content],
          task: task,
          agent: role,
          model: response[:model],
          usage: response[:usage],
          metadata: {
            provider: response[:provider],
            timestamp: response[:timestamp],
            streamed: true
          }
        )
      rescue StandardError => e
        Tasks::Result.new(
          content: nil,
          task: task,
          agent: role,
          error: e,
          success: false
        )
      end

      # Agent role identifier
      def role
        raise NotImplementedError, "#{self.class} must implement #role"
      end

      # Default model tier config key (e.g., :architect, :implementer, :reviewer)
      def model_config_key
        role
      end

      protected

      def default_system_prompt
        raise NotImplementedError, "#{self.class} must implement #default_system_prompt"
      end

      def build_messages(task)
        messages = [{ role: "system", content: system_prompt }]

        # Add context from previous results if available
        if task.context&.any?
          context_text = task.context.map { |c| "Previous result:\n#{c}" }.join("\n\n")
          messages << { role: "user", content: context_text }
          messages << { role: "assistant", content: "I understand the context. I'll proceed with the task." }
        end

        messages << { role: "user", content: task.description }
        messages
      end

      def get_provider_for_task(task)
        difficulty = task.difficulty || Tasks::DifficultyScorer.score(task)
        model = select_model(difficulty)
        Providers::Registry.create_for_model(model)
      end

      def select_model(difficulty)
        config = OrchestraAI.configuration
        model_config = config.models.send(model_config_key)
        thresholds = config.difficulty

        if difficulty < thresholds.simple_threshold
          model_config.simple
        elsif difficulty < thresholds.moderate_threshold
          model_config.moderate
        else
          model_config.complex
        end
      end
    end
  end
end
