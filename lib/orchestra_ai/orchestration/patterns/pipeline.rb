# frozen_string_literal: true

module OrchestraAI
  module Orchestration
    module Patterns
      class Pipeline
        attr_reader :stages, :results

        def initialize
          @stages = []
          @results = {}
        end

        # Add a stage to the pipeline
        # @param name [Symbol] Stage identifier
        # @yield [task, context] Block that executes the stage
        # @yieldparam task [Tasks::Definition] The original task
        # @yieldparam context [Hash] Results from previous stages
        # @yieldreturn [Tasks::Result] The stage result
        def stage(name, &block)
          @stages << { name: name, handler: block }
          self
        end

        # Execute the pipeline
        # @param task [Tasks::Definition] The task to process
        # @return [PipelineResult]
        def execute(task, **options)
          @results = {}
          current_task = task

          stages.each do |stage_def|
            name = stage_def[:name]
            handler = stage_def[:handler]

            result = handler.call(current_task, @results)
            @results[name] = result

            if result.failed?
              return PipelineResult.new(
                results: @results,
                completed_stages: @results.keys,
                failed_stage: name,
                success: false
              )
            end
          end

          PipelineResult.new(
            results: @results,
            completed_stages: @results.keys,
            failed_stage: nil,
            success: true
          )
        end

        # Create a standard architect -> implementer -> reviewer pipeline
        def self.standard(**options)
          new.tap do |p|
            p.stage(:plan) { |t, _| OrchestraAI.architect.execute(t, **options) }
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
        end
      end

      class PipelineResult
        attr_reader :results, :completed_stages, :failed_stage

        def initialize(results:, completed_stages:, failed_stage:, success:)
          @results = results
          @completed_stages = completed_stages
          @failed_stage = failed_stage
          @success = success
        end

        def success?
          @success
        end

        def failed?
          !success?
        end

        # Get result for a specific stage
        def [](stage_name)
          results[stage_name]
        end

        # Get the final result
        def final
          return nil if results.empty?

          results[completed_stages.last]
        end

        # Get combined content from all stages
        def content
          results.map do |name, result|
            "## #{name.to_s.capitalize}\n\n#{result.content}"
          end.join("\n\n---\n\n")
        end

        def total_cost
          costs = results.values.map(&:cost).compact
          return nil if costs.empty?

          {
            input: costs.sum { |c| c[:input] },
            output: costs.sum { |c| c[:output] },
            total: costs.sum { |c| c[:total] }
          }
        end

        def stage_costs
          results.transform_values(&:cost)
        end
      end
    end
  end
end
