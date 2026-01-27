# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-01-27

### Added

- Initial release
- Multi-provider support (OpenAI, Anthropic, Google)
- Role-based agents (Architect, Implementer, Reviewer)
- Task difficulty scoring and automatic model selection
- Execution patterns: Sequential, Parallel, Pipeline, Router
- Retry policies with exponential backoff
- Circuit breaker for fault tolerance
- Context management and conversation memory
- CLI tool with execute, models, config, and score commands
- Testing utilities: MockProvider and RSpec matchers
