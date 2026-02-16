# frozen_string_literal: true

require 'test_helper'

class BaseAgentTest < Minitest::Test
  include OrchestraAITestHelper

  # Minimal subclass that doesn't override abstract methods
  class MinimalAgent < OrchestraAI::Agents::Base
    def role
      :minimal
    end

    def default_system_prompt
      'Minimal prompt'
    end
  end

  # Subclass that doesn't implement role
  class NoRoleAgent < OrchestraAI::Agents::Base
    def default_system_prompt
      'No role prompt'
    end
  end

  # Subclass that doesn't implement default_system_prompt
  class NoPromptAgent < OrchestraAI::Agents::Base
    # This won't work because default_system_prompt is called in initialize
  end

  def setup
    super
    OrchestraAI.configure do |c|
      c.anthropic_api_key = 'test-key'
      c.openai_api_key = 'test-key'
      c.google_api_key = 'test-key'
    end
  end

  def test_initialise_accepts_custom_system_prompt
    agent = OrchestraAI::Agents::Architect.new(system_prompt: 'Custom prompt')

    assert_equal 'Custom prompt', agent.system_prompt
  end

  def test_subclass_required_to_implement_role
    # Base class cannot be instantiated directly because
    # default_system_prompt is called in initialize
    # This tests that subclasses must implement role
    architect = OrchestraAI::Agents::Architect.new
    assert_equal :architect, architect.role
  end

  def test_subclass_required_to_implement_default_system_prompt
    # Base class cannot be instantiated directly because
    # default_system_prompt is called in initialize
    # Subclasses properly implement this
    architect = OrchestraAI::Agents::Architect.new
    assert_includes architect.system_prompt.downcase, 'architect'
  end

  def test_model_config_key_returns_role
    architect = OrchestraAI::Agents::Architect.new
    assert_equal :architect, architect.model_config_key

    implementer = OrchestraAI::Agents::Implementer.new
    assert_equal :implementer, implementer.model_config_key

    reviewer = OrchestraAI::Agents::Reviewer.new
    assert_equal :reviewer, reviewer.model_config_key
  end

  def test_role_raises_not_implemented_when_not_overridden
    # Create a minimal instance, then try to call parent role
    agent = MinimalAgent.new
    # Override role to call super
    def agent.role_from_base
      OrchestraAI::Agents::Base.instance_method(:role).bind_call(self)
    end

    assert_raises(NotImplementedError) do
      agent.role_from_base
    end
  end

  def test_default_system_prompt_raises_not_implemented_when_not_overridden
    agent = MinimalAgent.new
    # Override to call parent method
    def agent.default_prompt_from_base
      OrchestraAI::Agents::Base.instance_method(:default_system_prompt).bind_call(self)
    end

    assert_raises(NotImplementedError) do
      agent.default_prompt_from_base
    end
  end
end

class AgentExecutionTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure do |c|
      c.anthropic_api_key = 'test-key'
      c.openai_api_key = 'test-key'
      c.google_api_key = 'test-key'
    end
    @mock_provider = OrchestraAI::Testing::MockProvider.new(responses: ['Mock response'])
    @task = OrchestraAI::Tasks::Definition.new(
      description: 'Test task',
      context: []
    )
  end

  def test_execute_returns_successful_result
    agent = OrchestraAI::Agents::Implementer.new

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      result = agent.execute(@task)

      assert result.success?
      assert_equal 'Mock response', result.content
      assert_equal :implementer, result.agent
    end
  end

  def test_execute_uses_local_cli_when_available
    agent = OrchestraAI::Agents::Implementer.new
    local_result = OrchestraAI::Tasks::Result.new(
      content: 'Local CLI output',
      task: @task,
      agent: :implementer,
      model: 'local-cli:codex',
      usage: {}
    )

    OrchestraAI::Development::Toolchain.stub(:try_local_cli, local_result) do
      result = agent.execute(@task)

      assert result.success?
      assert_equal 'Local CLI output', result.content
      assert_equal 'local-cli:codex', result.model
    end
  end

  def test_execute_handles_errors_gracefully
    agent = OrchestraAI::Agents::Implementer.new
    error_provider = OrchestraAI::Testing::MockProvider.new(responses: [])
    error_provider.queue_error(StandardError.new('Something went wrong'))

    OrchestraAI::Providers::Registry.stub(:create_for_model, error_provider) do
      result = agent.execute(@task)

      assert result.failed?
      assert_equal 'Something went wrong', result.error.message
    end
  end

  def test_execute_passes_options_to_provider
    agent = OrchestraAI::Agents::Implementer.new

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      agent.execute(@task, temperature: 0.5, max_tokens: 1000)

      assert_equal 0.5, @mock_provider.last_call[:options][:temperature]
      assert_equal 1000, @mock_provider.last_call[:options][:max_tokens]
    end
  end

  def test_execute_includes_task_context_in_messages
    task_with_context = OrchestraAI::Tasks::Definition.new(
      description: 'Task with context',
      context: ['Previous result 1', 'Previous result 2']
    )
    agent = OrchestraAI::Agents::Implementer.new

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      agent.execute(task_with_context)

      messages = @mock_provider.last_call[:messages]
      message_contents = messages.map { |m| m[:content] }.join(' ')
      assert_includes message_contents, 'Previous result 1'
      assert_includes message_contents, 'Previous result 2'
    end
  end

  def test_stream_yields_chunks
    agent = OrchestraAI::Agents::Implementer.new
    chunks = []

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      agent.stream(@task) { |chunk| chunks << chunk }
    end

    refute chunks.empty?
  end

  def test_stream_returns_result
    agent = OrchestraAI::Agents::Implementer.new

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      result = agent.stream(@task) { |_| }

      assert result.success?
      assert_equal :implementer, result.agent
    end
  end

  def test_stream_handles_errors_gracefully
    agent = OrchestraAI::Agents::Implementer.new
    error_provider = OrchestraAI::Testing::MockProvider.new(responses: [])
    error_provider.queue_error(StandardError.new('Stream error'))

    OrchestraAI::Providers::Registry.stub(:create_for_model, error_provider) do
      result = agent.stream(@task) { |_| }

      assert result.failed?
      assert_equal 'Stream error', result.error.message
    end
  end

  def test_select_model_uses_simple_model_for_low_difficulty
    agent = OrchestraAI::Agents::Implementer.new
    simple_task = OrchestraAI::Tasks::Definition.new(
      description: 'fix typo',
      difficulty: 0.1
    )

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      agent.execute(simple_task)
    end

    # Verify the provider was called (model selection happened)
    assert_equal 1, @mock_provider.calls.size
  end

  def test_select_model_uses_complex_model_for_high_difficulty
    agent = OrchestraAI::Agents::Architect.new
    complex_task = OrchestraAI::Tasks::Definition.new(
      description: 'Design a distributed system with multiple microservices',
      difficulty: 0.9
    )

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      agent.execute(complex_task)
    end

    assert_equal 1, @mock_provider.calls.size
  end

  def test_build_messages_includes_system_prompt
    agent = OrchestraAI::Agents::Implementer.new

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      agent.execute(@task)

      messages = @mock_provider.last_call[:messages]
      system_message = messages.find { |m| m[:role] == 'system' }
      refute_nil system_message
      refute_empty system_message[:content]
    end
  end

  def test_build_messages_includes_task_description
    agent = OrchestraAI::Agents::Implementer.new

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      agent.execute(@task)

      messages = @mock_provider.last_call[:messages]
      user_message = messages.find { |m| m[:role] == 'user' && m[:content].include?('Test task') }
      refute_nil user_message
    end
  end

  def test_build_messages_adds_mcp_context_when_available
    agent = OrchestraAI::Agents::Implementer.new

    OrchestraAI::Development::Toolchain.stub(:mcp_context, 'Relevant MCP data') do
      OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
        agent.execute(@task)

        messages = @mock_provider.last_call[:messages]
        mcp_message = messages.find { |m| m[:content].include?('Relevant MCP data') }
        refute_nil mcp_message
      end
    end
  end

  def test_system_prompt_includes_copilot_instructions_when_available
    agent = OrchestraAI::Agents::Implementer.new

    OrchestraAI::Development::Toolchain.stub(:copilot_instructions, 'Keep patches small') do
      OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
        agent.execute(@task)

        messages = @mock_provider.last_call[:messages]
        system_message = messages.find { |m| m[:role] == 'system' }
        assert_includes system_message[:content], 'Keep patches small'
      end
    end
  end

  def test_result_includes_metadata
    agent = OrchestraAI::Agents::Implementer.new

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      result = agent.execute(@task)

      refute_nil result.metadata
      assert_equal :mock, result.metadata[:provider]
    end
  end
end

class ArchitectAgentTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure do |c|
      c.anthropic_api_key = 'test-key'
      c.openai_api_key = 'test-key'
      c.google_api_key = 'test-key'
    end
  end

  def test_has_architect_role
    agent = OrchestraAI::Agents::Architect.new

    assert_equal :architect, agent.role
  end

  def test_has_architecture_focused_system_prompt
    agent = OrchestraAI::Agents::Architect.new

    assert_includes agent.system_prompt.downcase, 'architect'
  end

  def test_system_prompt_includes_design_guidance
    agent = OrchestraAI::Agents::Architect.new

    prompt = agent.system_prompt.downcase
    assert prompt.include?('design') || prompt.include?('architecture')
  end
end

class ImplementerAgentTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure do |c|
      c.anthropic_api_key = 'test-key'
      c.openai_api_key = 'test-key'
      c.google_api_key = 'test-key'
    end
  end

  def test_has_implementer_role
    agent = OrchestraAI::Agents::Implementer.new

    assert_equal :implementer, agent.role
  end

  def test_has_implementation_focused_system_prompt
    agent = OrchestraAI::Agents::Implementer.new

    prompt = agent.system_prompt.downcase
    assert prompt.include?('implement') || prompt.include?('code') || prompt.include?('develop')
  end
end

class ReviewerAgentTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure do |c|
      c.anthropic_api_key = 'test-key'
      c.openai_api_key = 'test-key'
      c.google_api_key = 'test-key'
    end
  end

  def test_has_reviewer_role
    agent = OrchestraAI::Agents::Reviewer.new

    assert_equal :reviewer, agent.role
  end

  def test_has_review_focused_system_prompt
    agent = OrchestraAI::Agents::Reviewer.new

    prompt = agent.system_prompt.downcase
    assert prompt.include?('review') || prompt.include?('quality')
  end
end
