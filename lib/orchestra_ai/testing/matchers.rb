# frozen_string_literal: true

module OrchestraAI
  module Testing
    # Minitest assertions for OrchestraAI
    module Assertions
      # Assert that a result used a specific agent
      def assert_used_agent(expected_agent, result, msg = nil)
        expected = expected_agent.to_sym
        actual = result.agent
        msg ||= "Expected result to have used agent :#{expected}, but used :#{actual}"
        assert_equal expected, actual, msg
      end

      # Assert that a result did not use a specific agent
      def refute_used_agent(expected_agent, result, msg = nil)
        expected = expected_agent.to_sym
        actual = result.agent
        msg ||= "Expected result not to have used agent :#{expected}"
        refute_equal expected, actual, msg
      end

      # Assert that a result used a specific model
      def assert_used_model(expected_model, result, msg = nil)
        actual = result.model
        msg ||= "Expected result to have used model '#{expected_model}', but used '#{actual}'"
        assert_equal expected_model, actual, msg
      end

      # Assert that a result did not use a specific model
      def refute_used_model(expected_model, result, msg = nil)
        actual = result.model
        msg ||= "Expected result not to have used model '#{expected_model}'"
        refute_equal expected_model, actual, msg
      end

      # Assert that a task is classified as a specific difficulty tier
      def assert_classified_as(expected_tier, task, msg = nil)
        expected = expected_tier.to_sym
        actual = Tasks::DifficultyScorer.classify(task)
        msg ||= "Expected task to be classified as :#{expected}, but was :#{actual}"
        assert_equal expected, actual, msg
      end

      # Assert that a task is not classified as a specific difficulty tier
      def refute_classified_as(expected_tier, task, msg = nil)
        expected = expected_tier.to_sym
        actual = Tasks::DifficultyScorer.classify(task)
        msg ||= "Expected task not to be classified as :#{expected}"
        refute_equal expected, actual, msg
      end

      # Assert that a result is successful
      def assert_successful(result, msg = nil)
        msg ||= begin
          error_msg = result.error ? ": #{result.error.message}" : ''
          "Expected result to be successful#{error_msg}"
        end
        assert result.success?, msg
      end

      # Assert that a result is not successful (failed)
      def refute_successful(result, msg = nil)
        msg ||= 'Expected result not to be successful'
        refute result.success?, msg
      end

      alias assert_failed refute_successful
    end

    # Legacy RSpec-style matchers (for compatibility)
    module Matchers
      # Matcher for checking if a task was executed with a specific agent
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

      # Matcher for checking if a task was executed with a specific model
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

      # Matcher for checking task difficulty classification
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

      # Matcher for checking if result is successful
      class BeSuccessful
        def matches?(result)
          @result = result
          result.success?
        end

        def failure_message
          error_msg = @result.error ? ": #{@result.error.message}" : ''
          "expected result to be successful#{error_msg}"
        end

        def failure_message_when_negated
          'expected result not to be successful'
        end
      end

      # Helper methods
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

# Auto-include Minitest assertions if available
Minitest::Test.include OrchestraAI::Testing::Assertions if defined?(Minitest::Test)
