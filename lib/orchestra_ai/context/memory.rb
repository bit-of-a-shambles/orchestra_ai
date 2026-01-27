# frozen_string_literal: true

module OrchestraAI
  module Context
    class Memory
      attr_reader :conversations, :facts

      def initialize
        @conversations = {}
        @facts = {}
      end

      # Get or create a conversation
      def conversation(id)
        @conversations[id] ||= Conversation.new(id: id)
      end

      # Store a fact
      def remember(key, value)
        @facts[key] = {
          value: value,
          timestamp: Time.now.utc
        }
        self
      end

      # Retrieve a fact
      def recall(key)
        @facts[key]&.fetch(:value, nil)
      end

      # Forget a fact
      def forget(key)
        @facts.delete(key)
        self
      end

      # Get all facts as context
      def facts_context
        return nil if facts.empty?

        facts.map { |k, v| "#{k}: #{v[:value]}" }.join("\n")
      end

      # Clear all memory
      def clear
        @conversations = {}
        @facts = {}
        self
      end

      # Export memory state
      def to_h
        {
          conversations: conversations.transform_values do |conv|
            {
              id: conv.id,
              messages: conv.messages,
              created_at: conv.created_at
            }
          end,
          facts: facts
        }
      end

      # Import memory state
      def from_h(data)
        data[:facts]&.each { |k, v| @facts[k.to_s] = v }
        self
      end
    end
  end
end
