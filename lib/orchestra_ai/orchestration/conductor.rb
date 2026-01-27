# frozen_string_literal: true

module OrchestraAI
  module Orchestration
    class Conductor
      # Execute a task with automatic routing
      def execute(task, **options)
        pattern = options.delete(:pattern) || :auto
        agent = options.delete(:agent)

        case pattern
        when :auto
          auto_execute(task, **options)
        when :pipeline
          pipeline_execute(task, **options)
        when :parallel
          raise ArgumentError, "Use #parallel for parallel execution"
        else
          raise ArgumentError, "Unknown pattern: #{pattern}"
        end
      end

      # Create a pipeline for sequential multi-stage execution
      def pipeline(&block)
        Patterns::Pipeline.new.tap do |p|
          block&.call(p)
        end
      end

      # Execute multiple tasks in parallel
      def parallel(*tasks, **options)
        Patterns::Parallel.new(tasks, **options)
      end

      # Create a sequential executor
      def sequential(*tasks, **options)
        Patterns::Sequential.new(tasks, **options)
      end

      # Create an intelligent router
      def router(&block)
        Patterns::Router.new.tap do |r|
          block&.call(r)
        end
      end

      private

      def auto_execute(task, **options)
        difficulty = Tasks::DifficultyScorer.score(task)
        classification = Tasks::DifficultyScorer.classify(task)

        # For simple tasks, use implementer directly
        # For complex tasks, use the full pipeline
        case classification
        when :simple
          OrchestraAI.implementer.execute(task, **options)
        when :moderate
          # Two-stage: implement then review
          impl_result = OrchestraAI.implementer.execute(task, **options)
          return impl_result if impl_result.failed?

          review_task = task.dup_with(
            description: "Review the following implementation:\n\n#{impl_result.content}",
            context: [impl_result.to_context]
          )
          OrchestraAI.reviewer.execute(review_task, **options)
        when :complex
          # Full pipeline: architect -> implement -> review
          pipeline_execute(task, **options)
        end
      end

      def pipeline_execute(task, **options)
        pipe = pipeline do |p|
          p.stage(:plan) { |t, _ctx| OrchestraAI.architect.execute(t, **options) }
          p.stage(:implement) do |t, ctx|
            impl_task = t.dup_with(context: [ctx[:plan]&.to_context].compact)
            OrchestraAI.implementer.execute(impl_task, **options)
          end
          p.stage(:review) do |t, ctx|
            review_task = t.dup_with(
              description: "Review this implementation:\n\n#{ctx[:implement]&.content}",
              context: [ctx[:plan]&.to_context, ctx[:implement]&.to_context].compact
            )
            OrchestraAI.reviewer.execute(review_task, **options)
          end
        end

        pipe.execute(task)
      end
    end
  end
end
