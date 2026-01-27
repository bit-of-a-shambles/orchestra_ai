# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
  add_group 'Agents', 'lib/orchestra_ai/agents'
  add_group 'Orchestration', 'lib/orchestra_ai/orchestration'
  add_group 'Providers', 'lib/orchestra_ai/providers'
  add_group 'Tasks', 'lib/orchestra_ai/tasks'
  add_group 'Reliability', 'lib/orchestra_ai/reliability'
  add_group 'Testing', 'lib/orchestra_ai/testing'
end

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
