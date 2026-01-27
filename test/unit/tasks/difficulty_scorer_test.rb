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
end
