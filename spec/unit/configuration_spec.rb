# frozen_string_literal: true

require "spec_helper"

RSpec.describe OrchestraAI::Configuration do
  describe "settings" do
    it "has default model settings" do
      config = described_class.new

      expect(config.config.models.architect.simple).to eq("claude-3-5-haiku-latest")
      expect(config.config.models.architect.moderate).to eq("claude-sonnet-4-20250514")
      expect(config.config.models.architect.complex).to eq("claude-opus-4-20250514")
    end

    it "has default difficulty thresholds" do
      config = described_class.new

      expect(config.config.difficulty.simple_threshold).to eq(0.33)
      expect(config.config.difficulty.moderate_threshold).to eq(0.66)
    end

    it "has default retry settings" do
      config = described_class.new

      expect(config.config.retry.max_attempts).to eq(3)
      expect(config.config.retry.base_delay).to eq(1.0)
    end
  end

  describe "#provider_available?" do
    it "returns false when no API key is set" do
      config = described_class.new

      expect(config.provider_available?(:anthropic)).to be false
    end
  end
end
