# frozen_string_literal: true

module OrchestraAI
  class Configuration
    # API Keys
    attr_accessor :anthropic_api_key, :openai_api_key, :google_api_key

    # Admin API Keys (for billing/usage APIs)
    attr_accessor :anthropic_admin_key, :openai_admin_key

    # SSL verification (set to false if you have certificate issues)
    attr_accessor :ssl_verify

    # Logging
    attr_accessor :logger, :log_level

    # Nested config objects
    attr_reader :models, :difficulty, :retry_config, :circuit_breaker, :parallel, :budget, :development

    def initialize
      @anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
      @openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
      @google_api_key = ENV.fetch('GOOGLE_API_KEY', nil)
      @anthropic_admin_key = ENV.fetch('ANTHROPIC_ADMIN_KEY', nil)
      @openai_admin_key = ENV.fetch('OPENAI_ADMIN_KEY', nil)
      @ssl_verify = ENV.fetch('ORCHESTRA_SSL_VERIFY', 'true') != 'false'
      @logger = nil
      @log_level = :info

      @models = ModelsConfig.new
      @difficulty = DifficultyConfig.new
      @retry_config = RetryConfig.new
      @circuit_breaker = CircuitBreakerConfig.new
      @parallel = ParallelConfig.new
      @budget = BudgetConfig.new
      @development = DevelopmentConfig.new
    end

    def validate!
      errors = []

      if anthropic_api_key.nil? && openai_api_key.nil? && google_api_key.nil?
        errors << 'At least one API key must be configured'
      end

      raise ConfigurationError, errors.join(', ') unless errors.empty?

      true
    end

    def provider_available?(provider)
      case provider.to_sym
      when :anthropic then !anthropic_api_key.nil?
      when :openai then !openai_api_key.nil?
      when :google then !google_api_key.nil?
      else false
      end
    end

    # Nested config classes
    class ModelsConfig
      attr_reader :architect, :implementer, :reviewer

      def initialize
        @architect = RoleModelsConfig.new(
          simple: 'gemini-2.5-flash',
          moderate: 'gpt-5.2-codex',
          complex: 'claude-opus-4.5'
        )
        @implementer = RoleModelsConfig.new(
          simple: 'gemini-2.5-flash',
          moderate: 'gemini-2.5-flash',
          complex: 'gpt-5.2-codex'
        )
        @reviewer = RoleModelsConfig.new(
          simple: 'gemini-2.5-flash',
          moderate: 'gpt-5.2-codex',
          complex: 'claude-opus-4.5'
        )
      end
    end

    class RoleModelsConfig
      attr_accessor :simple, :moderate, :complex

      def initialize(simple:, moderate:, complex:)
        @simple = simple
        @moderate = moderate
        @complex = complex
      end
    end

    class DifficultyConfig
      attr_accessor :simple_threshold, :moderate_threshold

      def initialize
        @simple_threshold = 0.33
        @moderate_threshold = 0.66
      end
    end

    class RetryConfig
      attr_accessor :max_attempts, :base_delay, :max_delay, :multiplier

      def initialize
        @max_attempts = 3
        @base_delay = 1.0
        @max_delay = 30.0
        @multiplier = 2.0
      end
    end

    class CircuitBreakerConfig
      attr_accessor :failure_threshold, :reset_timeout

      def initialize
        @failure_threshold = 5
        @reset_timeout = 60
      end
    end

    class ParallelConfig
      attr_accessor :max_threads, :timeout

      def initialize
        @max_threads = 4
        @timeout = 300
      end
    end

    class BudgetConfig
      attr_accessor :limits, :alert_threshold, :enforce_limits, :fallback_strategy

      FALLBACK_STRATEGIES = %i[downgrade reject warn].freeze

      def initialize
        @limits = { anthropic: nil, openai: nil, google: nil }
        @alert_threshold = 0.8
        @enforce_limits = false
        @fallback_strategy = :warn
      end

      def set_limit(provider, amount)
        provider = provider.to_sym
        raise ArgumentError, "Unknown provider: #{provider}" unless %i[anthropic openai google].include?(provider)

        @limits[provider] = amount&.to_f
      end

      def fallback_strategy=(strategy)
        strategy = strategy.to_sym
        unless FALLBACK_STRATEGIES.include?(strategy)
          raise ArgumentError, "Invalid fallback strategy: #{strategy}. Valid: #{FALLBACK_STRATEGIES.join(', ')}"
        end

        @fallback_strategy = strategy
      end

      def to_budget
        Costs::Budget.new(limits: @limits, alert_threshold: @alert_threshold)
      end
    end

    class DevelopmentConfig
      attr_accessor :enabled, :mcp_enabled, :mcp_context_command, :mcp_timeout, :mcp_context_max_chars,
                    :copilot_instructions_enabled, :copilot_instructions_path, :copilot_instructions_max_chars,
                    :coding_cli_enabled, :coding_cli_timeout
      attr_reader :coding_cli_order, :coding_cli_roles

      def initialize
        @enabled = ENV.fetch('ORCHESTRA_DEV_ACCELERATION', 'false') == 'true'
        @mcp_enabled = ENV.fetch('ORCHESTRA_MCP_ENABLED', 'true') != 'false'
        @mcp_context_command = ENV.fetch('ORCHESTRA_MCP_CONTEXT_COMMAND', nil)
        @mcp_timeout = ENV.fetch('ORCHESTRA_MCP_TIMEOUT', '5').to_i
        @mcp_context_max_chars = ENV.fetch('ORCHESTRA_MCP_CONTEXT_MAX_CHARS', '4000').to_i

        @copilot_instructions_enabled = ENV.fetch('ORCHESTRA_COPILOT_INSTRUCTIONS_ENABLED', 'true') != 'false'
        @copilot_instructions_path = ENV.fetch('ORCHESTRA_COPILOT_INSTRUCTIONS_PATH',
                                               '.github/copilot-instructions.md')
        @copilot_instructions_max_chars = ENV.fetch('ORCHESTRA_COPILOT_INSTRUCTIONS_MAX_CHARS', '4000').to_i

        @coding_cli_enabled = ENV.fetch('ORCHESTRA_CODING_CLI_ENABLED', 'true') != 'false'
        @coding_cli_timeout = ENV.fetch('ORCHESTRA_CODING_CLI_TIMEOUT', '120').to_i
        @coding_cli_order = parse_cli_list(ENV.fetch('ORCHESTRA_CODING_CLI_ORDER', 'codex,opencode,pi,claude'))
        @coding_cli_roles = parse_role_list(ENV.fetch('ORCHESTRA_CODING_CLI_ROLES', 'implementer,reviewer'))
      end

      def coding_cli_order=(list)
        @coding_cli_order = parse_cli_list(list)
      end

      def coding_cli_roles=(list)
        @coding_cli_roles = parse_role_list(list)
      end

      def role_enabled?(role)
        @coding_cli_roles.include?(role.to_sym)
      end

      private

      def parse_cli_list(list)
        Array(list).join(',').split(',').map { |v| v.strip.downcase }.reject(&:empty?).uniq
      end

      def parse_role_list(list)
        Array(list).join(',').split(',').map { |v| v.strip.downcase.to_sym }.reject(&:empty?).uniq
      end
    end
  end
end
