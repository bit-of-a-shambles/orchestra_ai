# frozen_string_literal: true

require 'test_helper'

class OrchestraAITest < Minitest::Test
  include OrchestraAITestHelper

  def test_configuration_returns_configuration_instance
    assert_instance_of OrchestraAI::Configuration, OrchestraAI.configuration
  end

  def test_configure_yields_configuration
    OrchestraAI.configure do |c|
      c.anthropic_api_key = 'test-key'
      assert_instance_of OrchestraAI::Configuration, c
    end
  end

  def test_reset_configuration_creates_new_instance
    OrchestraAI.configure { |c| c.anthropic_api_key = 'test-key' }
    old_config = OrchestraAI.configuration

    OrchestraAI.reset_configuration!
    new_config = OrchestraAI.configuration

    refute_same old_config, new_config
  end

  def test_architect_returns_architect_agent
    OrchestraAI.configure { |c| c.anthropic_api_key = 'test-key' }
    assert_instance_of OrchestraAI::Agents::Architect, OrchestraAI.architect
  end

  def test_implementer_returns_implementer_agent
    OrchestraAI.configure { |c| c.anthropic_api_key = 'test-key' }
    assert_instance_of OrchestraAI::Agents::Implementer, OrchestraAI.implementer
  end

  def test_reviewer_returns_reviewer_agent
    OrchestraAI.configure { |c| c.anthropic_api_key = 'test-key' }
    assert_instance_of OrchestraAI::Agents::Reviewer, OrchestraAI.reviewer
  end

  def test_conductor_returns_conductor_instance
    OrchestraAI.configure { |c| c.anthropic_api_key = 'test-key' }
    assert_instance_of OrchestraAI::Orchestration::Conductor, OrchestraAI.conductor
  end

  def test_reset_clears_all_cached_instances
    OrchestraAI.configure { |c| c.anthropic_api_key = 'test-key' }
    old_architect = OrchestraAI.architect

    OrchestraAI.reset!
    OrchestraAI.configure { |c| c.anthropic_api_key = 'test-key' }
    new_architect = OrchestraAI.architect

    refute_same old_architect, new_architect
  end

  def test_logger_returns_logger_instance
    OrchestraAI.configure { |c| c.anthropic_api_key = 'test-key' }
    assert_respond_to OrchestraAI.logger, :info
    assert_respond_to OrchestraAI.logger, :warn
    assert_respond_to OrchestraAI.logger, :error
  end

  def test_execute_delegates_to_conductor
    OrchestraAI.configure { |c| c.anthropic_api_key = 'test-key' }
    task = OrchestraAI::Tasks::Definition.new(description: 'Test task')

    # Mock the conductor to verify delegation
    mock_conductor = Minitest::Mock.new
    mock_conductor.expect(:execute, nil, [task], pattern: :auto)

    OrchestraAI.stub(:conductor, mock_conductor) do
      OrchestraAI.execute(task, pattern: :auto)
    end

    mock_conductor.verify
  end
end
