# frozen_string_literal: true

require "spec_helper"

RSpec.describe OrchestraAI::Testing::MockProvider do
  describe "#complete" do
    it "returns mock responses" do
      provider = described_class.new(responses: ["Hello, world!"])
      messages = [{ role: "user", content: "Hi" }]

      result = provider.complete(messages)

      expect(result[:content]).to eq("Hello, world!")
    end

    it "records calls" do
      provider = described_class.new
      messages = [{ role: "user", content: "Test message" }]

      provider.complete(messages, temperature: 0.7)

      expect(provider.calls.size).to eq(1)
      expect(provider.last_call[:method]).to eq(:complete)
      expect(provider.last_call[:options][:temperature]).to eq(0.7)
    end

    it "cycles through multiple responses" do
      provider = described_class.new(responses: ["First", "Second"])
      messages = [{ role: "user", content: "Hi" }]

      first = provider.complete(messages)
      second = provider.complete(messages)
      third = provider.complete(messages)

      expect(first[:content]).to eq("First")
      expect(second[:content]).to eq("Second")
      expect(third[:content]).to eq("First")
    end
  end

  describe "#queue_error" do
    it "raises the queued error" do
      provider = described_class.new(responses: [])
      provider.queue_error(StandardError.new("Test error"))
      messages = [{ role: "user", content: "Hi" }]

      expect { provider.complete(messages) }.to raise_error("Test error")
    end
  end

  describe "#received_message?" do
    it "checks if message was received" do
      provider = described_class.new
      provider.complete([{ role: "user", content: "Hello there" }])

      expect(provider.received_message?("Hello")).to be true
      expect(provider.received_message?("Goodbye")).to be false
    end
  end
end
