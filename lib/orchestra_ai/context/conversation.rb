# frozen_string_literal: true

module OrchestraAI
  module Context
    class Conversation
      attr_reader :id, :messages, :results, :created_at

      def initialize(id: nil)
        @id = id || SecureRandom.uuid
        @messages = []
        @results = []
        @created_at = Time.now.utc
      end

      # Add a user message
      def user(content)
        add_message(role: :user, content: content)
        self
      end

      # Add an assistant message
      def assistant(content)
        add_message(role: :assistant, content: content)
        self
      end

      # Add a system message
      def system(content)
        add_message(role: :system, content: content)
        self
      end

      # Add a result from task execution
      def add_result(result)
        @results << result
        assistant(result.content) if result.success?
        self
      end

      # Build messages array for provider
      def to_messages
        messages.map do |msg|
          { role: msg[:role].to_s, content: msg[:content] }
        end
      end

      # Get context for a new task
      def to_context
        results.select(&:success?).map(&:to_context).compact
      end

      # Create a task with this conversation's context
      def create_task(description)
        Tasks::Definition.new(
          description: description,
          context: to_context
        )
      end

      # Clear conversation history
      def clear
        @messages = []
        @results = []
        self
      end

      # Token count estimation
      def estimated_tokens
        messages.sum { |m| m[:content].to_s.length / 4 }
      end

      # Truncate to fit within token limit
      def truncate(max_tokens: 100_000)
        while estimated_tokens > max_tokens && messages.size > 1
          # Keep system messages, remove oldest user/assistant pairs
          first_non_system = messages.find_index { |m| m[:role] != :system }
          break unless first_non_system

          @messages.delete_at(first_non_system)
        end
        self
      end

      private

      def add_message(role:, content:)
        @messages << {
          role: role,
          content: content,
          timestamp: Time.now.utc
        }
      end
    end
  end
end
