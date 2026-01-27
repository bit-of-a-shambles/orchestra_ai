# frozen_string_literal: true

module OrchestraAI
  module Orchestration
    module Patterns
      class Router
        attr_reader :routes, :default_route

        def initialize
          @routes = []
          @default_route = nil
        end

        # Add a route based on a condition
        # @param condition [Proc, Symbol] Condition to match
        # @yield [task] Block to execute when condition matches
        def route(condition = nil, &handler)
          @routes << { condition: condition, handler: handler }
          self
        end

        # Set default route when no conditions match
        def default(&handler)
          @default_route = handler
          self
        end

        # Route based on difficulty tier
        def route_by_difficulty(tier, &handler)
          route(->(t) { Tasks::DifficultyScorer.classify(t) == tier }, &handler)
          self
        end

        # Route based on keyword presence
        def route_by_keywords(*keywords, &handler)
          route(lambda { |t|
            desc = t.description.downcase
            keywords.any? { |kw| desc.include?(kw.downcase) }
          }, &handler)
          self
        end

        # Execute routing logic
        def execute(task, **options)
          handler = find_handler(task)

          if handler
            handler.call(task, **options)
          elsif default_route
            default_route.call(task, **options)
          else
            # Fall back to auto execution
            OrchestraAI.conductor.execute(task, pattern: :auto, **options)
          end
        end

        # Create a standard router with difficulty-based routing
        def self.by_difficulty(**options)
          new.tap do |r|
            r.route_by_difficulty(:simple) do |task, **opts|
              OrchestraAI.implementer.execute(task, **opts.merge(options))
            end

            r.route_by_difficulty(:moderate) do |task, **opts|
              OrchestraAI.conductor.sequential(
                task,
                task.dup_with(description: "Review: #{task.description}")
              ).execute(**opts.merge(options))
            end

            r.route_by_difficulty(:complex) do |task, **opts|
              Pipeline.standard(**opts.merge(options)).execute(task)
            end
          end
        end

        # Create a router for code-related tasks
        def self.for_code(**options)
          new.tap do |r|
            r.route_by_keywords("bug", "fix", "error", "issue") do |task, **opts|
              OrchestraAI.implementer.execute(task, **opts.merge(options))
            end

            r.route_by_keywords("design", "architect", "plan", "structure") do |task, **opts|
              OrchestraAI.architect.execute(task, **opts.merge(options))
            end

            r.route_by_keywords("review", "check", "audit", "analyze") do |task, **opts|
              OrchestraAI.reviewer.execute(task, **opts.merge(options))
            end

            r.default do |task, **opts|
              OrchestraAI.conductor.execute(task, pattern: :auto, **opts.merge(options))
            end
          end
        end

        private

        def find_handler(task)
          routes.each do |route_def|
            condition = route_def[:condition]
            handler = route_def[:handler]

            matches = case condition
                      when Proc
                        condition.call(task)
                      when Symbol
                        task.respond_to?(condition) && task.send(condition)
                      when nil
                        true
                      else
                        false
                      end

            return handler if matches
          end

          nil
        end
      end
    end
  end
end
