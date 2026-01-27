# frozen_string_literal: true

require 'test_helper'

class RouterPatternTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure do |c|
      c.anthropic_api_key = 'test-key'
      c.openai_api_key = 'test-key'
      c.google_api_key = 'test-key'
    end
    @router = OrchestraAI::Orchestration::Patterns::Router.new
  end

  def test_initialise_with_empty_routes
    assert_empty @router.routes
    assert_nil @router.default_route
  end

  def test_route_adds_route_to_router
    @router.route(:test_condition) { |t| 'result' }

    assert_equal 1, @router.routes.size
  end

  def test_route_returns_self_for_chaining
    result = @router.route { |t| 'result' }

    assert_same @router, result
  end

  def test_default_sets_default_route
    @router.default { |t| 'default result' }

    refute_nil @router.default_route
  end

  def test_default_returns_self_for_chaining
    result = @router.default { |t| 'default' }

    assert_same @router, result
  end

  def test_route_by_difficulty_adds_difficulty_based_route
    @router.route_by_difficulty(:simple) { |t| 'simple handler' }

    assert_equal 1, @router.routes.size
  end

  def test_route_by_difficulty_returns_self_for_chaining
    result = @router.route_by_difficulty(:complex) { |t| 'complex' }

    assert_same @router, result
  end

  def test_route_by_keywords_adds_keyword_based_route
    @router.route_by_keywords('bug', 'fix', 'error') { |t| 'bug handler' }

    assert_equal 1, @router.routes.size
  end

  def test_route_by_keywords_returns_self_for_chaining
    result = @router.route_by_keywords('test') { |t| 'result' }

    assert_same @router, result
  end

  def test_by_difficulty_creates_preconfigured_router
    router = OrchestraAI::Orchestration::Patterns::Router.by_difficulty

    assert_instance_of OrchestraAI::Orchestration::Patterns::Router, router
    assert router.routes.size >= 3  # simple, moderate, complex
  end

  def test_for_code_creates_code_focused_router
    router = OrchestraAI::Orchestration::Patterns::Router.for_code

    assert_instance_of OrchestraAI::Orchestration::Patterns::Router, router
    assert router.routes.size >= 1
  end
end

class RouterExecutionTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure do |c|
      c.anthropic_api_key = 'test-key'
      c.openai_api_key = 'test-key'
      c.google_api_key = 'test-key'
    end
    @router = OrchestraAI::Orchestration::Patterns::Router.new
    @mock_provider = OrchestraAI::Testing::MockProvider.new(responses: ['Routed response'])
    @task = OrchestraAI::Tasks::Definition.new(description: 'Test task')
  end

  def test_execute_with_matching_proc_condition
    result_value = nil
    @router.route(->(t) { t.description.include?('Test') }) do |t|
      result_value = 'matched'
      result_value
    end

    @router.execute(@task)

    assert_equal 'matched', result_value
  end

  def test_execute_with_matching_symbol_condition
    task = OrchestraAI::Tasks::Definition.new(description: 'Test', difficulty: 0.5)

    result_value = nil
    @router.route(:difficulty) do |t|
      result_value = 'matched'
      result_value
    end

    @router.execute(task)

    assert_equal 'matched', result_value
  end

  def test_execute_with_nil_condition_always_matches
    result_value = nil
    @router.route(nil) do |t|
      result_value = 'always matched'
      result_value
    end

    @router.execute(@task)

    assert_equal 'always matched', result_value
  end

  def test_execute_falls_back_to_default_route
    result_value = nil
    @router.route(->(t) { false }) { |t| 'never' }
    @router.default do |t|
      result_value = 'default'
      result_value
    end

    @router.execute(@task)

    assert_equal 'default', result_value
  end

  def test_execute_falls_back_to_conductor_when_no_default
    @router.route(->(t) { false }) { |t| 'never' }

    OrchestraAI::Providers::Registry.stub(:create_for_model, @mock_provider) do
      result = @router.execute(@task)

      # Falls back to conductor.execute with :auto
      assert result.success?
    end
  end

  def test_execute_with_route_by_difficulty
    simple_task = OrchestraAI::Tasks::Definition.new(description: 'fix typo', difficulty: 0.1)
    result_value = nil

    @router.route_by_difficulty(:simple) do |t|
      result_value = 'simple route'
      result_value
    end

    @router.execute(simple_task)

    assert_equal 'simple route', result_value
  end

  def test_execute_with_route_by_keywords
    bug_task = OrchestraAI::Tasks::Definition.new(description: 'fix the bug in login')
    result_value = nil

    @router.route_by_keywords('bug', 'error') do |t|
      result_value = 'bug route'
      result_value
    end

    @router.execute(bug_task)

    assert_equal 'bug route', result_value
  end

  def test_execute_passes_options_to_handler
    received_options = nil
    @router.route(nil) do |t, **opts|
      received_options = opts
      'result'
    end

    @router.execute(@task, temperature: 0.5, max_tokens: 100)

    assert_equal 0.5, received_options[:temperature]
    assert_equal 100, received_options[:max_tokens]
  end

  def test_execute_first_matching_route_wins
    match_order = []
    @router.route(->(t) { true }) do |t|
      match_order << 'first'
      'first result'
    end
    @router.route(->(t) { true }) do |t|
      match_order << 'second'
      'second result'
    end

    result = @router.execute(@task)

    assert_equal ['first'], match_order
    assert_equal 'first result', result
  end

  def test_execute_with_by_difficulty_router
    mock_provider = OrchestraAI::Testing::MockProvider.new(responses: ['Response'])
    simple_task = OrchestraAI::Tasks::Definition.new(description: 'fix typo', difficulty: 0.1)

    router = OrchestraAI::Orchestration::Patterns::Router.by_difficulty

    OrchestraAI::Providers::Registry.stub(:create_for_model, mock_provider) do
      result = router.execute(simple_task)

      # Simple tasks should be handled by implementer
      assert result.success?
    end
  end

  def test_execute_with_for_code_router_handles_bug_tasks
    mock_provider = OrchestraAI::Testing::MockProvider.new(responses: ['Fixed'])
    bug_task = OrchestraAI::Tasks::Definition.new(description: 'fix bug in login')

    router = OrchestraAI::Orchestration::Patterns::Router.for_code

    OrchestraAI::Providers::Registry.stub(:create_for_model, mock_provider) do
      result = router.execute(bug_task)

      assert result.success?
    end
  end

  def test_execute_with_for_code_router_handles_design_tasks
    mock_provider = OrchestraAI::Testing::MockProvider.new(responses: ['Design'])
    design_task = OrchestraAI::Tasks::Definition.new(description: 'design the new architecture')

    router = OrchestraAI::Orchestration::Patterns::Router.for_code

    OrchestraAI::Providers::Registry.stub(:create_for_model, mock_provider) do
      result = router.execute(design_task)

      assert result.success?
      assert_equal :architect, result.agent
    end
  end

  def test_execute_with_for_code_router_handles_review_tasks
    mock_provider = OrchestraAI::Testing::MockProvider.new(responses: ['Looks good'])
    review_task = OrchestraAI::Tasks::Definition.new(description: 'review this code')

    router = OrchestraAI::Orchestration::Patterns::Router.for_code

    OrchestraAI::Providers::Registry.stub(:create_for_model, mock_provider) do
      result = router.execute(review_task)

      assert result.success?
      assert_equal :reviewer, result.agent
    end
  end

  def test_execute_with_for_code_router_falls_back_to_default
    mock_provider = OrchestraAI::Testing::MockProvider.new(responses: ['Done'])
    generic_task = OrchestraAI::Tasks::Definition.new(description: 'something random')

    router = OrchestraAI::Orchestration::Patterns::Router.for_code

    OrchestraAI::Providers::Registry.stub(:create_for_model, mock_provider) do
      result = router.execute(generic_task)

      assert result.success?
    end
  end

  def test_execute_with_by_difficulty_handles_moderate_tasks
    mock_provider = OrchestraAI::Testing::MockProvider.new(responses: ['Response 1', 'Response 2'])
    moderate_task = OrchestraAI::Tasks::Definition.new(description: 'moderate task', difficulty: 0.5)

    router = OrchestraAI::Orchestration::Patterns::Router.by_difficulty

    OrchestraAI::Providers::Registry.stub(:create_for_model, mock_provider) do
      result = router.execute(moderate_task)

      assert_instance_of OrchestraAI::Orchestration::Patterns::SequentialResult, result
    end
  end

  def test_execute_with_by_difficulty_handles_complex_tasks
    mock_provider = OrchestraAI::Testing::MockProvider.new(responses: ['Plan', 'Impl', 'Review'])
    complex_task = OrchestraAI::Tasks::Definition.new(description: 'complex task', difficulty: 0.9)

    router = OrchestraAI::Orchestration::Patterns::Router.by_difficulty

    OrchestraAI::Providers::Registry.stub(:create_for_model, mock_provider) do
      result = router.execute(complex_task)

      assert_instance_of OrchestraAI::Orchestration::Patterns::PipelineResult, result
    end
  end

  def test_find_handler_with_non_matching_condition
    @router.route(->(t) { false }) { |t| 'never' }
    @router.route(:nonexistent_method) { |t| 'also never' }

    # Both conditions should fail, fall back to default
    @router.default { |t| 'default' }

    result = @router.execute(@task)

    assert_equal 'default', result
  end

  def test_route_condition_with_other_type_returns_false
    # Use a string condition (not Proc, Symbol, or nil)
    @router.routes << { condition: 'string_condition', handler: proc { |t| 'should not match' } }
    @router.default { |t| 'default' }

    result = @router.execute(@task)

    assert_equal 'default', result
  end
end
