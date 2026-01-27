# frozen_string_literal: true

require 'test_helper'
require 'open3'

class CLITest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    @exe_path = File.expand_path('../../exe/orchestra', __dir__)
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

  def test_cli_has_execute_command
    content = File.read(@exe_path)
    assert_match(/desc "execute DESCRIPTION"/, content,
                 'CLI should have execute command')
  end

  def test_cli_has_models_command
    content = File.read(@exe_path)
    assert_match(/desc "models"/, content,
                 'CLI should have models command')
  end

  def test_cli_has_config_command
    content = File.read(@exe_path)
    assert_match(/desc "config"/, content,
                 'CLI should have config command')
  end

  def test_cli_has_score_command
    content = File.read(@exe_path)
    assert_match(/desc "score DESCRIPTION"/, content,
                 'CLI should have score command')
  end

  def test_cli_has_version_command
    content = File.read(@exe_path)
    assert_match(/desc "version"/, content,
                 'CLI should have version command')
  end

  def test_cli_starts_thor
    content = File.read(@exe_path)
    assert_match(/OrchestraAI::CLI\.start\(ARGV\)/, content,
                 'CLI should start Thor with ARGV')
  end

  def test_cli_has_pattern_option_for_execute
    content = File.read(@exe_path)
    assert_match(/option :pattern.*type: :string.*default: "auto"/, content,
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

  def test_cli_has_budget_command
    content = File.read(@exe_path)
    assert_match(/desc "budget"/, content,
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
end
