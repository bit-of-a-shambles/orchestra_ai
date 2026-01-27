# frozen_string_literal: true

require "concurrent"

module OrchestraAI
  module Orchestration
    module Patterns
      class Parallel
        attr_reader :tasks, :agent, :results

        def initialize(tasks, agent: nil, max_threads: nil, timeout: nil)
          @tasks = Array(tasks)
          @agent = agent
          @max_threads = max_threads || OrchestraAI.configuration.config.parallel.max_threads
          @timeout = timeout || OrchestraAI.configuration.config.parallel.timeout
          @results = []
        end

        def execute(**options)
          pool = Concurrent::FixedThreadPool.new(@max_threads)
          futures = []

          tasks.each do |task|
            future = Concurrent::Future.execute(executor: pool) do
              execute_task(task, **options)
            end
            futures << { task: task, future: future }
          end

          # Wait for all futures with timeout
          @results = futures.map do |item|
            begin
              result = item[:future].value(@timeout)
              if result.nil? && item[:future].rejected?
                Tasks::Result.new(
                  content: nil,
                  task: item[:task],
                  agent: agent || :auto,
                  error: item[:future].reason || StandardError.new("Task failed"),
                  success: false
                )
              elsif result.nil?
                Tasks::Result.new(
                  content: nil,
                  task: item[:task],
                  agent: agent || :auto,
                  error: StandardError.new("Task timed out"),
                  success: false
                )
              else
                result
              end
            rescue StandardError => e
              Tasks::Result.new(
                content: nil,
                task: item[:task],
                agent: agent || :auto,
                error: e,
                success: false
              )
            end
          end

          pool.shutdown
          pool.wait_for_termination(5)

          ParallelResult.new(@results)
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

      class ParallelResult
        attr_reader :results

        def initialize(results)
          @results = results
        end

        def success?
          results.all?(&:success?)
        end

        def failed?
          results.any?(&:failed?)
        end

        def successful
          results.select(&:success?)
        end

        def failures
          results.select(&:failed?)
        end

        def to_a
          results
        end

        def size
          results.size
        end

        def success_rate
          return 0.0 if results.empty?

          successful.size.to_f / results.size
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
