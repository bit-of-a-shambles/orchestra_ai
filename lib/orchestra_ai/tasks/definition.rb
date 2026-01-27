# frozen_string_literal: true

require "securerandom"

module OrchestraAI
  module Tasks
    class Definition
      attr_reader :id, :description, :metadata, :context, :created_at
      attr_accessor :difficulty, :assigned_model, :assigned_agent

      def initialize(description:, id: nil, difficulty: nil, context: nil, metadata: nil)
        @id = id || SecureRandom.uuid
        @description = description
        @difficulty = difficulty
        @context = Array(context)
        @metadata = metadata || {}
        @created_at = Time.now.utc
        @assigned_model = nil
        @assigned_agent = nil

        validate!
      end

      def add_context(content)
        @context << content
        self
      end

      def with_metadata(key, value)
        @metadata[key] = value
        self
      end

      def to_h
        {
          id: id,
          description: description,
          difficulty: difficulty,
          context: context,
          metadata: metadata,
          assigned_model: assigned_model,
          assigned_agent: assigned_agent,
          created_at: created_at
        }
      end

      def dup_with(**overrides)
        self.class.new(
          description: overrides.fetch(:description, description),
          id: overrides.fetch(:id, SecureRandom.uuid),
          difficulty: overrides.fetch(:difficulty, difficulty),
          context: overrides.fetch(:context, context.dup),
          metadata: overrides.fetch(:metadata, metadata.dup)
        )
      end

      private

      def validate!
        raise TaskValidationError, "Description is required" if description.nil? || description.empty?
      end
    end
  end
end
