# frozen_string_literal: true

require_relative "lib/orchestra_ai/version"

Gem::Specification.new do |spec|
  spec.name = "orchestra_ai"
  spec.version = OrchestraAI::VERSION
  spec.authors = ["Duarte Martins"]
  spec.email = ["duarte@example.com"]

  spec.summary = "AI agent orchestrator for multi-provider workflows"
  spec.description = "Orchestrate multiple AI agents (OpenAI, Gemini, Claude) with role-based execution, parallel processing, task difficulty scoring, and cost optimization."
  spec.homepage = "https://github.com/Duartemartins/orchestra_ai"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "bin"
  spec.executables = ["orchestra"]
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "anthropic", "~> 0.3"
  spec.add_dependency "ruby-openai", "~> 7.0"
  spec.add_dependency "gemini-ai", "~> 4.0"
  spec.add_dependency "concurrent-ruby", "~> 1.2"
  spec.add_dependency "dry-configurable", "~> 1.0"
  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "zeitwerk", "~> 2.6"

  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "vcr", "~> 6.2"
  spec.add_development_dependency "webmock", "~> 3.19"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rubocop", "~> 1.50"
end
