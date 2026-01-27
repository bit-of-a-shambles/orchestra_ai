# frozen_string_literal: true

module OrchestraAI
  # Base error class for all OrchestraAI errors
  class Error < StandardError; end

  # Configuration errors
  class ConfigurationError < Error; end
  class MissingApiKeyError < ConfigurationError; end

  # Provider errors
  class ProviderError < Error
    attr_reader :provider, :original_error

    def initialize(message, provider: nil, original_error: nil)
      @provider = provider
      @original_error = original_error
      super(message)
    end
  end

  class ProviderNotFoundError < ProviderError; end
  class ProviderAuthenticationError < ProviderError; end
  class ProviderRateLimitError < ProviderError; end
  class ProviderTimeoutError < ProviderError; end

  # Task errors
  class TaskError < Error; end
  class TaskValidationError < TaskError; end
  class TaskExecutionError < TaskError; end

  # Agent errors
  class AgentError < Error; end
  class AgentNotConfiguredError < AgentError; end

  # Orchestration errors
  class OrchestrationError < Error; end
  class PipelineError < OrchestrationError; end
  class ParallelExecutionError < OrchestrationError
    attr_reader :failed_tasks, :successful_tasks

    def initialize(message, failed_tasks: [], successful_tasks: [])
      @failed_tasks = failed_tasks
      @successful_tasks = successful_tasks
      super(message)
    end
  end

  # Circuit breaker errors
  class CircuitOpenError < Error
    attr_reader :provider, :reset_at

    def initialize(message, provider: nil, reset_at: nil)
      @provider = provider
      @reset_at = reset_at
      super(message)
    end
  end
end
