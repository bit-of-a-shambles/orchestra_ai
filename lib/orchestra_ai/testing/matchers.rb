# frozen_string_literal: true

module OrchestraAI
  module Testing
    module Matchers
      # RSpec matcher for checking if a task was executed with a specific agent
      class HaveUsedAgent
        def initialize(expected_agent)
          @expected_agent = expected_agent.to_sym
        end

        def matches?(result)
          @result = result
          result.agent == @expected_agent
        end

        def failure_message
          "expected result to have used agent :#{@expected_agent}, " \
            "but used :#{@result.agent}"
        end

        def failure_message_when_negated
          "expected result not to have used agent :#{@expected_agent}"
        end
      end

      # RSpec matcher for checking if a task was executed with a specific model
      class HaveUsedModel
        def initialize(expected_model)
          @expected_model = expected_model
        end

        def matches?(result)
          @result = result
          result.model == @expected_model
        end

        def failure_message
          "expected result to have used model '#{@expected_model}', " \
            "but used '#{@result.model}'"
        end

        def failure_message_when_negated
          "expected result not to have used model '#{@expected_model}'"
        end
      end

      # RSpec matcher for checking task difficulty classification
      class BeClassifiedAs
        def initialize(expected_tier)
          @expected_tier = expected_tier.to_sym
        end

        def matches?(task)
          @task = task
          @actual_tier = Tasks::DifficultyScorer.classify(task)
          @actual_tier == @expected_tier
        end

        def failure_message
          "expected task to be classified as :#{@expected_tier}, " \
            "but was :#{@actual_tier}"
        end

        def failure_message_when_negated
          "expected task not to be classified as :#{@expected_tier}"
        end
      end

      # RSpec matcher for checking if result is successful
      class BeSuccessful
        def matches?(result)
          @result = result
          result.success?
        end

        def failure_message
          error_msg = @result.error ? ": #{@result.error.message}" : ""
          "expected result to be successful#{error_msg}"
        end

        def failure_message_when_negated
          "expected result not to be successful"
        end
      end

      # Helper methods for RSpec
      def have_used_agent(agent)
        HaveUsedAgent.new(agent)
      end

      def have_used_model(model)
        HaveUsedModel.new(model)
      end

      def be_classified_as(tier)
        BeClassifiedAs.new(tier)
      end

      def be_successful
        BeSuccessful.new
      end
    end
  end
end

# Auto-include in RSpec if available
if defined?(RSpec)
  RSpec.configure do |config|
    config.include OrchestraAI::Testing::Matchers
  end
end
