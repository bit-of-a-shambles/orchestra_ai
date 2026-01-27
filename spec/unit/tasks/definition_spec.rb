# frozen_string_literal: true

require "spec_helper"

RSpec.describe OrchestraAI::Tasks::Definition do
  describe "#initialize" do
    it "creates a task with description" do
      task = described_class.new(description: "Test task")

      expect(task.description).to eq("Test task")
      expect(task.id).not_to be_nil
      expect(task.context).to eq([])
      expect(task.metadata).to eq({})
    end

    it "raises error without description" do
      expect {
        described_class.new(description: "")
      }.to raise_error(OrchestraAI::TaskValidationError)
    end

    it "accepts custom id" do
      task = described_class.new(description: "Test", id: "custom-id")

      expect(task.id).to eq("custom-id")
    end

    it "accepts context" do
      task = described_class.new(
        description: "Test",
        context: ["Previous result"]
      )

      expect(task.context).to eq(["Previous result"])
    end
  end

  describe "#add_context" do
    it "adds context to the task" do
      task = described_class.new(description: "Test")
      task.add_context("New context")

      expect(task.context).to include("New context")
    end

    it "returns self for chaining" do
      task = described_class.new(description: "Test")
      result = task.add_context("Context")

      expect(result).to eq(task)
    end
  end

  describe "#dup_with" do
    it "creates a copy with overrides" do
      original = described_class.new(
        description: "Original",
        difficulty: 0.5
      )

      copy = original.dup_with(description: "Modified")

      expect(copy.description).to eq("Modified")
      expect(copy.difficulty).to eq(0.5)
      expect(copy.id).not_to eq(original.id)
    end
  end
end
