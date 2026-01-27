# frozen_string_literal: true

module OrchestraAI
  module Orchestration
    module Patterns
      class Sequential
        attr_reader :tasks, :agent, :results

        def initialize(tasks, agent: nil, stop_on_failure: true)
          @tasks = Array(tasks)
          @agent = agent
          @stop_on_failure = stop_on_failure
          @results = []
        end

        def execute(**options)
          @results = []

          tasks.each_with_index do |task, index|
            # Add context from previous results
            if index.positive? && results.last&.success?
              task = task.dup_with(
                context: task.context + [results.last.to_context]
              )
            end

            result = execute_task(task, **options)
            @results << result

            if result.failed? && @stop_on_failure
              break
            end
          end

          SequentialResult.new(results)
        end

        private

        def execute_task(task, **options)
          if agent
            get_agent(agent).execute(task, **options)
          else
            OrchestraAI.conductor.execute(task, pattern: :auto, **options)
          end
        end

        def get_agent(agent_type)
          case agent_type.to_sym
          when :architect then OrchestraAI.architect
          when :implementer then OrchestraAI.implementer
          when :reviewer then OrchestraAI.reviewer
          else
            raise ArgumentError, "Unknown agent: #{agent_type}"
          end
        end
      end

      class SequentialResult
        attr_reader :results

        def initialize(results)
          @results = results
        end

        def success?
          results.all?(&:success?)
        end

        def failed?
          !success?
        end

        def first_failure
          results.find(&:failed?)
        end

        def last_result
          results.last
        end

        def content
          results.map(&:content).join("\n\n---\n\n")
        end

        def to_a
          results
        end

        def size
          results.size
        end

        def total_cost
          costs = results.map(&:cost).compact
          return nil if costs.empty?

          {
            input: costs.sum { |c| c[:input] },
            output: costs.sum { |c| c[:output] },
            total: costs.sum { |c| c[:total] }
          }
        end
      end
    end
  end
end
