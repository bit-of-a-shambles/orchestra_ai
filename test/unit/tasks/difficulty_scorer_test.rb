# frozen_string_literal: true

require 'test_helper'

class DifficultyScorerTest < Minitest::Test
  include OrchestraAITestHelper

  def setup
    super
    OrchestraAI.configure do |c|
      c.anthropic_api_key = 'test-key'
    end
  end

  def test_scores_simple_tasks_low
    task = OrchestraAI::Tasks::Definition.new(
      description: 'Fix a typo in the readme'
    )

    score = OrchestraAI::Tasks::DifficultyScorer.score(task)

    assert score < 0.4, "Expected score < 0.4, got #{score}"
  end

  def test_scores_complex_tasks_high
    task = OrchestraAI::Tasks::Definition.new(
      description: 'Design a distributed system architecture for handling ' \
                   'real-time authentication with machine learning-based ' \
                   'security optimisation and concurrent processing'
    )

    score = OrchestraAI::Tasks::DifficultyScorer.score(task)

    assert score > 0.5, "Expected score > 0.5, got #{score}"
  end

  def test_considers_context_in_scoring
    simple_task = OrchestraAI::Tasks::Definition.new(
      description: 'Add a button'
    )

    task_with_context = OrchestraAI::Tasks::Definition.new(
      description: 'Add a button',
      context: ['Previous implementation details...' * 100]
    )

    simple_score = OrchestraAI::Tasks::DifficultyScorer.score(simple_task)
    context_score = OrchestraAI::Tasks::DifficultyScorer.score(task_with_context)

    assert context_score > simple_score,
           "Expected context_score (#{context_score}) > simple_score (#{simple_score})"
  end

  def test_classifies_simple_tasks
    task = OrchestraAI::Tasks::Definition.new(
      description: 'Fix typo'
    )

    assert_equal :simple, OrchestraAI::Tasks::DifficultyScorer.classify(task)
  end

  def test_classifies_tasks_with_preset_difficulty
    task = OrchestraAI::Tasks::Definition.new(
      description: 'A task',
      difficulty: 0.8
    )

    assert_equal :complex, OrchestraAI::Tasks::DifficultyScorer.classify(task)
  end

  def test_classifies_complex_descriptions_as_not_simple
    task = OrchestraAI::Tasks::Definition.new(
      description: 'Design and architect a distributed system with scalable authentication, ' \
                   'real-time streaming optimisation, and performance optimisation'
    )

    refute_equal :simple, OrchestraAI::Tasks::DifficultyScorer.classify(task)
  end

  def test_very_long_descriptions_score_higher
    short_task = OrchestraAI::Tasks::Definition.new(
      description: 'Short task'
    )

    # Create a very long description (over 500 chars)
    long_description = 'This is a very long task description that should trigger higher length scoring. ' * 10
    long_task = OrchestraAI::Tasks::Definition.new(
      description: long_description
    )

    short_score = OrchestraAI::Tasks::DifficultyScorer.score(short_task)
    long_score = OrchestraAI::Tasks::DifficultyScorer.score(long_task)

    assert long_score > short_score,
           "Expected long_score (#{long_score}) > short_score (#{short_score})"
  end

  def test_context_with_many_items_scores_higher
    task_few_ctx = OrchestraAI::Tasks::Definition.new(
      description: 'Task',
      context: ['One context item']
    )

    task_many_ctx = OrchestraAI::Tasks::Definition.new(
      description: 'Task',
      context: ['Context 1', 'Context 2', 'Context 3', 'Context 4', 'Context 5']
    )

    few_score = OrchestraAI::Tasks::DifficultyScorer.score(task_few_ctx)
    many_score = OrchestraAI::Tasks::DifficultyScorer.score(task_many_ctx)

    assert many_score > few_score,
           "Expected many_score (#{many_score}) > few_score (#{few_score})"
  end

  def test_context_with_very_long_content_scores_higher
    task_short_ctx = OrchestraAI::Tasks::Definition.new(
      description: 'Task',
      context: ['Short']
    )

    # Very long context should hit the length_score branch
    very_long_context = 'A' * 10_000 # Over 5000 chars
    task_long_ctx = OrchestraAI::Tasks::Definition.new(
      description: 'Task',
      context: [very_long_context]
    )

    short_score = OrchestraAI::Tasks::DifficultyScorer.score(task_short_ctx)
    long_score = OrchestraAI::Tasks::DifficultyScorer.score(task_long_ctx)

    assert long_score > short_score,
           "Expected long_score (#{long_score}) > short_score (#{short_score})"
  end
end
