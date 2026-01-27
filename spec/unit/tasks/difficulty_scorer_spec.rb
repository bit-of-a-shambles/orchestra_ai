# frozen_string_literal: true

require "spec_helper"

RSpec.describe OrchestraAI::Tasks::DifficultyScorer do
  before do
    OrchestraAI.configure do |c|
      c.anthropic_api_key = "test-key"
    end
  end

  describe ".score" do
    it "scores simple tasks low" do
      task = OrchestraAI::Tasks::Definition.new(
        description: "Fix a typo in the readme"
      )

      score = described_class.score(task)

      expect(score).to be < 0.4
    end

    it "scores complex tasks high" do
      task = OrchestraAI::Tasks::Definition.new(
        description: "Design a distributed system architecture for handling " \
                     "real-time authentication with machine learning-based " \
                     "security optimization and concurrent processing"
      )

      score = described_class.score(task)

      expect(score).to be > 0.5
    end

    it "considers context in scoring" do
      simple_task = OrchestraAI::Tasks::Definition.new(
        description: "Add a button"
      )

      task_with_context = OrchestraAI::Tasks::Definition.new(
        description: "Add a button",
        context: ["Previous implementation details..." * 100]
      )

      simple_score = described_class.score(simple_task)
      context_score = described_class.score(task_with_context)

      expect(context_score).to be > simple_score
    end
  end

  describe ".classify" do
    it "classifies simple tasks" do
      task = OrchestraAI::Tasks::Definition.new(
        description: "Fix typo"
      )

      expect(described_class.classify(task)).to eq(:simple)
    end

    it "classifies tasks with preset difficulty" do
      task = OrchestraAI::Tasks::Definition.new(
        description: "A task",
        difficulty: 0.8
      )

      expect(described_class.classify(task)).to eq(:complex)
    end

    it "classifies complex descriptions as not simple" do
      task = OrchestraAI::Tasks::Definition.new(
        description: "Design and architect a distributed system with scalable authentication, " \
                     "real-time streaming optimization, and performance optimization"
      )

      expect(described_class.classify(task)).not_to eq(:simple)
    end
  end
end
