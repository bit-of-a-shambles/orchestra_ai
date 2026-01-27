# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'minitest/pride'
require 'orchestra_ai'
require 'webmock/minitest'
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'test/cassettes'
  config.hook_into :webmock
  config.filter_sensitive_data('<ANTHROPIC_API_KEY>') { ENV.fetch('ANTHROPIC_API_KEY', nil) }
  config.filter_sensitive_data('<OPENAI_API_KEY>') { ENV.fetch('OPENAI_API_KEY', nil) }
  config.filter_sensitive_data('<GOOGLE_API_KEY>') { ENV.fetch('GOOGLE_API_KEY', nil) }
end

module OrchestraAITestHelper
  def setup
    OrchestraAI.reset!
    super
  end
end
