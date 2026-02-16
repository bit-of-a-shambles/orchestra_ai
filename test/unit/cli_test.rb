# frozen_string_literal: true

require 'test_helper'
require 'open3'
require 'stringio'
require 'ostruct'

# Load the CLI class from exe/orchestra
exe_path = File.expand_path('../../exe/orchestra', __dir__)
# Read file and eval to load classes without running CLI.start
cli_content = File.read(exe_path)
# Remove the CLI.start call at the end
cli_content = cli_content.gsub(/^OrchestraAI::CLI\.start\(ARGV\).*$/, '')
eval(cli_content, binding, exe_path) # rubocop:disable Security/Eval

class CLITest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    @exe_path = File.expand_path('../../exe/orchestra', __dir__)
    @original_stdout = $stdout
    @original_stderr = $stderr
    OrchestraAI.reset!
  end

  def teardown
    $stdout = @original_stdout
    $stderr = @original_stderr
  end

  def capture_output
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
    { stdout: $stdout.string, stderr: $stderr.string }
  ensure
    $stdout = @original_stdout
    $stderr = @original_stderr
  end

  def test_cli_file_exists
    assert File.exist?(@exe_path), "CLI executable should exist at #{@exe_path}"
  end

  def test_cli_is_valid_ruby
    # Check syntax without executing
    stdout, stderr, status = Open3.capture3('ruby', '-c', @exe_path)
    assert status.success?, "CLI should be valid Ruby syntax: #{stderr}"
    assert_match(/Syntax OK/, stdout)
  end

  def test_cli_defines_orchestra_ai_cli_class
    content = File.read(@exe_path)
    assert_match(/class CLI < Thor/, content,
                 'CLI should define OrchestraAI::CLI class inheriting from Thor')
  end

  # -- Runtime tests for version command --

  def test_version_command_output
    output = capture_output { OrchestraAI::CLI.new.version }
    assert_match(/OrchestraAI/, output[:stdout])
    assert_match(/\d+\.\d+\.\d+/, output[:stdout])
  end

  # -- Runtime tests for config command --

  def test_config_command_shows_api_keys_section
    output = capture_output { OrchestraAI::CLI.new.config }
    assert_match(/API Keys:/, output[:stdout])
    assert_match(/Anthropic:/, output[:stdout])
    assert_match(/OpenAI:/, output[:stdout])
    assert_match(/Google:/, output[:stdout])
  end

  def test_config_command_shows_admin_keys_section
    output = capture_output { OrchestraAI::CLI.new.config }
    assert_match(/Admin Keys/, output[:stdout])
  end

  def test_config_command_shows_model_defaults
    output = capture_output { OrchestraAI::CLI.new.config }
    assert_match(/Model Defaults:/, output[:stdout])
    assert_match(/Architect:/, output[:stdout])
    assert_match(/Implementer:/, output[:stdout])
    assert_match(/Reviewer:/, output[:stdout])
  end

  def test_config_command_shows_difficulty_thresholds
    output = capture_output { OrchestraAI::CLI.new.config }
    assert_match(/Difficulty Thresholds:/, output[:stdout])
  end

  # -- Runtime tests for models command --

  def test_models_command_shows_available_models
    output = capture_output { OrchestraAI::CLI.new.models }
    assert_match(/Available Models:/, output[:stdout])
  end

  def test_models_command_shows_pricing_info
    output = capture_output { OrchestraAI::CLI.new.models }
    assert_match(/Input:/, output[:stdout])
    assert_match(/Output:/, output[:stdout])
    assert_match(%r{/1M tokens}, output[:stdout])
  end

  # -- Runtime tests for score command --

  def test_score_command_output_for_simple_task
    output = capture_output { OrchestraAI::CLI.new.score('fix typo') }
    assert_match(/Task:/, output[:stdout])
    assert_match(/Score:/, output[:stdout])
    assert_match(/Classification:/, output[:stdout])
    assert_match(/Model Selection:/, output[:stdout])
  end

  def test_score_command_shows_all_agents
    output = capture_output { OrchestraAI::CLI.new.score('test task') }
    assert_match(/Architect:/, output[:stdout])
    assert_match(/Implementer:/, output[:stdout])
    assert_match(/Reviewer:/, output[:stdout])
  end

  # -- Runtime tests for budget command --

  def test_budget_command_shows_status
    output = capture_output { OrchestraAI::CLI.new.invoke(:budget, [], {}) }
    assert_match(/Budget Status:/, output[:stdout])
  end

  def test_budget_command_shows_configuration
    output = capture_output { OrchestraAI::CLI.new.invoke(:budget, [], {}) }
    assert_match(/Alert threshold:/, output[:stdout])
    assert_match(/Enforce limits:/, output[:stdout])
    assert_match(/Fallback strategy:/, output[:stdout])
  end

  def test_budget_command_shows_per_provider_limits
    output = capture_output { OrchestraAI::CLI.new.invoke(:budget, [], {}) }
    assert_match(/Per-Provider Limits:/, output[:stdout])
    assert_match(/Anthropic:/, output[:stdout])
    assert_match(/Openai:/, output[:stdout])
    assert_match(/Google:/, output[:stdout])
  end

  def test_budget_command_shows_total_spent
    output = capture_output { OrchestraAI::CLI.new.invoke(:budget, [], {}) }
    assert_match(/Total spent:/, output[:stdout])
  end

  # -- Runtime tests for dev command --

  def test_dev_command_shows_development_acceleration_section
    output = capture_output { OrchestraAI::CLI.new.invoke(:dev, [], {}) }
    assert_match(/Development Acceleration:/, output[:stdout])
    assert_match(/MCP:/, output[:stdout])
    assert_match(/Coding CLIs:/, output[:stdout])
    assert_match(/GitHub Copilot:/, output[:stdout])
  end

  # -- CLI helper method tests --

  def test_get_agent_returns_architect
    cli = OrchestraAI::CLI.new
    agent = cli.send(:get_agent, 'architect')
    assert_instance_of OrchestraAI::Agents::Architect, agent
  end

  def test_get_agent_returns_implementer
    cli = OrchestraAI::CLI.new
    agent = cli.send(:get_agent, 'implementer')
    assert_instance_of OrchestraAI::Agents::Implementer, agent
  end

  def test_get_agent_returns_reviewer
    cli = OrchestraAI::CLI.new
    agent = cli.send(:get_agent, 'reviewer')
    assert_instance_of OrchestraAI::Agents::Reviewer, agent
  end

  def test_get_agent_raises_for_unknown_agent
    cli = OrchestraAI::CLI.new
    assert_raises(ArgumentError) do
      cli.send(:get_agent, 'unknown')
    end
  end

  def test_format_number_formats_thousands
    cli = OrchestraAI::CLI.new
    assert_equal '1,000', cli.send(:format_number, 1000)
    assert_equal '1,000,000', cli.send(:format_number, 1_000_000)
    assert_equal '123', cli.send(:format_number, 123)
  end

  # -- output_result tests --

  def test_output_result_with_successful_pipeline_result
    cli = OrchestraAI::CLI.new

    # Create a mock stage result
    stage_result = OpenStruct.new(
      content: 'Test content',
      cost: { input: 0.001, output: 0.002, total: 0.003 }
    )

    result = OrchestraAI::Orchestration::Patterns::PipelineResult.new(
      results: { plan: stage_result },
      completed_stages: [:plan],
      failed_stage: nil,
      success: true
    )

    output = capture_output { cli.send(:output_result, result) }
    assert_match(/Stages:.*plan/i, output[:stdout])
  end

  def test_output_result_with_failed_pipeline_result
    cli = OrchestraAI::CLI.new

    result = OrchestraAI::Orchestration::Patterns::PipelineResult.new(
      results: {},
      completed_stages: [],
      failed_stage: :plan,
      success: false
    )

    output = capture_output { cli.send(:output_result, result) }
    assert_match(/failed.*plan/i, output[:stdout])
  end

  # -- Thor command registration tests --

  def test_cli_has_all_required_commands
    commands = OrchestraAI::CLI.commands.keys
    assert_includes commands, 'execute'
    assert_includes commands, 'models'
    assert_includes commands, 'config'
    assert_includes commands, 'score'
    assert_includes commands, 'budget'
    assert_includes commands, 'usage'
    assert_includes commands, 'dev'
    assert_includes commands, 'version'
  end

  def test_execute_command_has_correct_options
    cmd = OrchestraAI::CLI.commands['execute']
    assert cmd.options.key?(:pattern)
    assert cmd.options.key?(:agent)
    assert cmd.options.key?(:stream)
    assert_equal 'auto', cmd.options[:pattern].default
    assert_equal false, cmd.options[:stream].default
  end

  def test_budget_command_has_fetch_option
    cmd = OrchestraAI::CLI.commands['budget']
    assert cmd.options.key?(:fetch)
    assert_equal false, cmd.options[:fetch].default
  end

  def test_dev_command_has_write_option
    cmd = OrchestraAI::CLI.commands['dev']
    assert cmd.options.key?(:write)
    assert_equal false, cmd.options[:write].default
  end

  def test_cli_exits_on_failure
    assert OrchestraAI::CLI.exit_on_failure?
  end

  # -- File content tests (existing tests) --

  def test_cli_has_execute_command_in_file
    content = File.read(@exe_path)
    assert_match(/desc ['"]execute DESCRIPTION['"]/, content,
                 'CLI should have execute command')
  end

  def test_cli_has_models_command_in_file
    content = File.read(@exe_path)
    assert_match(/desc ['"]models['"]/, content,
                 'CLI should have models command')
  end

  def test_cli_has_config_command_in_file
    content = File.read(@exe_path)
    assert_match(/desc ['"]config['"]/, content,
                 'CLI should have config command')
  end

  def test_cli_has_score_command_in_file
    content = File.read(@exe_path)
    assert_match(/desc ['"]score DESCRIPTION['"]/, content,
                 'CLI should have score command')
  end

  def test_cli_has_version_command_in_file
    content = File.read(@exe_path)
    assert_match(/desc ['"]version['"]/, content,
                 'CLI should have version command')
  end

  def test_cli_has_dev_command_in_file
    content = File.read(@exe_path)
    assert_match(/desc ['"]dev['"]/, content,
                 'CLI should have dev command')
  end

  def test_cli_starts_thor
    content = File.read(@exe_path)
    assert_match(/OrchestraAI::CLI\.start\(ARGV\)/, content,
                 'CLI should start Thor with ARGV')
  end

  def test_cli_has_pattern_option_for_execute
    content = File.read(@exe_path)
    assert_match(/option :pattern.*type: :string.*default: ['"]auto['"]/, content,
                 'Execute command should have pattern option with auto default')
  end

  def test_cli_has_agent_option_for_execute
    content = File.read(@exe_path)
    assert_match(/option :agent.*type: :string/, content,
                 'Execute command should have agent option')
  end

  def test_cli_has_stream_option_for_execute
    content = File.read(@exe_path)
    assert_match(/option :stream.*type: :boolean/, content,
                 'Execute command should have stream option')
  end

  def test_cli_handles_architect_agent
    content = File.read(@exe_path)
    assert_match(/when :architect then OrchestraAI\.architect/, content,
                 'CLI should handle architect agent')
  end

  def test_cli_handles_implementer_agent
    content = File.read(@exe_path)
    assert_match(/when :implementer then OrchestraAI\.implementer/, content,
                 'CLI should handle implementer agent')
  end

  def test_cli_handles_reviewer_agent
    content = File.read(@exe_path)
    assert_match(/when :reviewer then OrchestraAI\.reviewer/, content,
                 'CLI should handle reviewer agent')
  end

  def test_cli_has_budget_command_in_file
    content = File.read(@exe_path)
    assert_match(/desc ['"]budget['"]/, content,
                 'CLI should have budget command')
  end

  def test_cli_budget_shows_provider_limits
    content = File.read(@exe_path)
    assert_match(/Per-Provider Limits/, content,
                 'Budget command should show per-provider limits')
  end

  def test_cli_budget_shows_configuration
    content = File.read(@exe_path)
    assert_match(/Alert threshold/, content,
                 'Budget command should show alert threshold')
    assert_match(/Enforce limits/, content,
                 'Budget command should show enforce_limits setting')
    assert_match(/Fallback strategy/, content,
                 'Budget command should show fallback strategy')
  end

  def test_cli_does_not_use_configuration_dot_config
    content = File.read(@exe_path)
    refute_match(/OrchestraAI\.configuration\.config/, content,
                 'CLI should NOT use .configuration.config (method does not exist)')
  end

  def test_cli_config_command_uses_correct_api
    content = File.read(@exe_path)
    # Should use OrchestraAI.configuration directly
    assert_match(/cfg = OrchestraAI\.configuration/, content,
                 'Config command should use OrchestraAI.configuration directly')
  end

  def test_cli_budget_command_uses_correct_api
    content = File.read(@exe_path)
    # Should use OrchestraAI.configuration.budget
    assert_match(/budget_config = OrchestraAI\.configuration\.budget/, content,
                 'Budget command should use OrchestraAI.configuration.budget')
  end
end
