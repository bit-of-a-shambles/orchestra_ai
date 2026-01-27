# frozen_string_literal: true

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "orchestra_ai" => "OrchestraAI",
  "ruby_llm_provider" => "RubyLLMProvider"
)
loader.ignore("#{__dir__}/orchestra_ai/errors.rb")
loader.ignore("#{__dir__}/orchestra_ai/version.rb")
loader.ignore("#{__dir__}/orchestra_ai/configuration.rb")
# Ignore old provider files (no longer used)
loader.ignore("#{__dir__}/orchestra_ai/providers/anthropic.rb")
loader.ignore("#{__dir__}/orchestra_ai/providers/openai.rb")
loader.ignore("#{__dir__}/orchestra_ai/providers/google.rb")
loader.setup

require_relative "orchestra_ai/version"
require_relative "orchestra_ai/errors"
require_relative "orchestra_ai/configuration"

module OrchestraAI
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
      configuration.validate!
      configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    # Convenience accessors for agents
    def architect
      @architect ||= Agents::Architect.new
    end

    def implementer
      @implementer ||= Agents::Implementer.new
    end

    def reviewer
      @reviewer ||= Agents::Reviewer.new
    end

    # Convenience accessor for conductor
    def conductor
      @conductor ||= Orchestration::Conductor.new
    end

    # Quick execute with auto-routing
    def execute(task, **options)
      conductor.execute(task, **options)
    end

    # Reset all cached instances (useful for testing)
    def reset!
      @configuration = nil
      @architect = nil
      @implementer = nil
      @reviewer = nil
      @conductor = nil
    end

    def logger
      configuration.logger || default_logger
    end

    private

    def default_logger
      @default_logger ||= begin
        require "logger"
        Logger.new($stdout, level: configuration.log_level)
      end
    end
  end
end

loader.eager_load
