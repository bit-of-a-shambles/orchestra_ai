# frozen_string_literal: true

module OrchestraAI
  module Orchestration
    class Conductor
      attr_reader :budget, :tracker, :planner

      def initialize(budget: nil)
        @budget = budget || OrchestraAI.configuration.budget.to_budget
        @tracker = Costs::Tracker.new(budget: @budget)
        @planner = Costs::Planner.new(budget: @budget)
      end

      # Plan execution and return cost estimate before running
      def plan(task)
        @planner.plan(task)
      end

      # Execute a task with automatic routing
      def execute(task, **options)
        pattern = options.delete(:pattern) || :auto
        agent = options.delete(:agent)
        skip_planning = options.delete(:skip_planning) || false

        # Pre-execution cost planning (if budget enforcement is enabled)
        unless skip_planning
          execution_plan = plan(task)

          handle_budget_enforcement(execution_plan, options) if OrchestraAI.configuration.budget.enforce_limits
        end

        result = case pattern
                 when :auto
                   auto_execute(task, **options)
                 when :pipeline
                   pipeline_execute(task, **options)
                 when :parallel
                   raise ArgumentError, 'Use #parallel for parallel execution'
                 else
                   raise ArgumentError, "Unknown pattern: #{pattern}"
                 end

        # Track costs after execution
        track_result(result)

        result
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

      # Get savings report for this session
      def savings_report
        @tracker.savings_report
      end

      # Get savings summary (formatted string)
      def savings_summary
        @tracker.savings_summary
      end

      # Reset tracking for new session
      def reset_tracking
        @tracker.reset
        @budget.reset
      end

      private

      def handle_budget_enforcement(execution_plan, options)
        config = OrchestraAI.configuration.budget

        case execution_plan.sufficiency
        when :insufficient
          case config.fallback_strategy
          when :reject
            raise BudgetExceededError, 'Insufficient budget to execute task'
          when :warn
            warn '[OrchestraAI] Warning: Insufficient budget. Task may not complete satisfactorily.'
          when :downgrade
            # Use alternative models if available
            options[:models] = execution_plan.alternatives[:models] if execution_plan.alternatives
          end
        when :partial
          case config.fallback_strategy
          when :warn
            warn '[OrchestraAI] Warning: Partial budget available. Using cheaper alternatives.'
          when :downgrade
            options[:models] = execution_plan.alternatives[:models] if execution_plan.alternatives
          end
        end
      end

      def track_result(result)
        case result
        when Tasks::Result
          @tracker.record(result)
        when Patterns::PipelineResult
          result.results.each_value { |r| @tracker.record(r) if r.is_a?(Tasks::Result) }
        when Patterns::SequentialResult, Patterns::ParallelResult
          result.results.each { |r| @tracker.record(r) if r.is_a?(Tasks::Result) }
        end
      end

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
