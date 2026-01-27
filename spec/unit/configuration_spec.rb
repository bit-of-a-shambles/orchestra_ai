# frozen_string_literal: true

require "spec_helper"

RSpec.describe OrchestraAI::Configuration do
  describe "settings" do
    it "has default model settings" do
      config = described_class.new

      expect(config.models.architect.simple).to eq("claude-3-5-haiku-latest")
      expect(config.models.architect.moderate).to eq("claude-sonnet-4-20250514")
      expect(config.models.architect.complex).to eq("claude-opus-4-20250514")
    end

    it "has default difficulty thresholds" do
      config = described_class.new

      expect(config.difficulty.simple_threshold).to eq(0.33)
      expect(config.difficulty.moderate_threshold).to eq(0.66)
    end

    it "has default retry settings" do
      config = described_class.new

      expect(config.retry_config.max_attempts).to eq(3)
      expect(config.retry_config.base_delay).to eq(1.0)
    end
  end

  describe "#provider_available?" do
    it "returns false when no API key is set" do
      config = described_class.new
      config.anthropic_api_key = nil

      expect(config.provider_available?(:anthropic)).to be false
    end

    it "returns true when API key is set" do
      config = described_class.new
      config.anthropic_api_key = "test-key"

      expect(config.provider_available?(:anthropic)).to be true
    end
  end
end
