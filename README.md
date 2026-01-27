# OrchestraAI

A simple AI agent orchestrator with role-based execution, parallel processing, task difficulty scoring, and cost optimisation.

## Why OrchestraAI?

### Cost Savings

Using only Claude Opus 4 for everything is expensive. OrchestraAI automatically routes tasks to the most cost-effective model:

| Scenario | Model | Cost per 1M tokens | 100 tasks (avg 2K tokens) |
|----------|-------|-------------------|---------------------------|
| **All Opus** | claude-opus-4 | $15.00 input / $75.00 output | **~$18.00** |
| **OrchestraAI** | Mixed (70% simple, 25% moderate, 5% complex) | Weighted average | **~$1.80** |

**Up to 90% cost reduction** by intelligently routing simple tasks to cheaper models while reserving expensive models for truly complex work.

### Speed Improvements

Single-agent workflows are sequential. OrchestraAI parallelizes independent tasks:

| Workflow | Single Agent | OrchestraAI (Parallel) | Speedup |
|----------|-------------|------------------------|---------|
| 3 independent tasks | ~15s (5s × 3) | ~5s (concurrent) | **3×** |
| 10 independent tasks | ~50s | ~5s | **10×** |
| Pipeline (3 stages) | ~15s | ~15s (sequential by design) | 1× |

The **Pipeline pattern** ensures quality through staged review, while **Parallel pattern** maximizes throughput for batch operations.

### Right Model for the Job

| Task Type | Single Model Approach | OrchestraAI |
|-----------|----------------------|-------------|
| "Fix typo" | Opus ($$$) overkill | Flash (¢) perfect fit |
| "Design microservices" | Flash inadequate | Opus (appropriate) |
| "Write unit test" | Opus (slow) | Codex (optimised for code) |

## How It Works

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              OrchestraAI                                    │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
                        ┌────────────────────────┐
                        │   Task Description     │
                        │   "Build auth system"  │
                        └────────────────────────┘
                                     │
                                     ▼
                        ┌────────────────────────┐
                        │  Difficulty Scoring    │
                        │  ───────────────────   │
                        │  • Word complexity     │
                        │  • Context length      │
                        │  • Technical keywords  │
                        │  Score: 0.0 ──► 1.0    │
                        └────────────────────────┘
                                     │
              ┌──────────────────────┼──────────────────────┐
              │                      │                      │
              ▼                      ▼                      ▼
      ┌──────────────┐      ┌──────────────┐      ┌──────────────┐
      │    Simple    │      │   Moderate   │      │   Complex    │
      │   < 0.33     │      │  0.33 - 0.66 │      │    > 0.66    │
      └──────────────┘      └──────────────┘      └──────────────┘
              │                      │                      │
              ▼                      ▼                      ▼
      ┌──────────────┐      ┌──────────────┐      ┌──────────────┐
      │ gemini-2.0   │      │  gpt-5-codex │      │ claude-opus-4│
      │    flash     │      │              │      │              │
      │  $0.10/1M    │      │   $2.00/1M   │      │  $15.00/1M   │
      └──────────────┘      └──────────────┘      └──────────────┘


                         ── Pipeline Pattern ──

  ┌─────────────┐       ┌─────────────┐       ┌─────────────┐
  │  ARCHITECT  │ ────► │ IMPLEMENTER │ ────► │  REVIEWER   │
  │             │       │             │       │             │
  │  "Design    │       │  "Write     │       │  "Check     │
  │   the       │       │   tests &   │       │   for       │
  │   system"   │       │   code"     │       │   issues"   │
  └─────────────┘       └─────────────┘       └─────────────┘
        │                     │                     │
        ▼                     ▼                     ▼
   Uses best model      Uses best model       Uses best model
   for planning         for coding            for review


                      ── TDD Workflow (Pipeline) ──

  ┌─────────────┐       ┌─────────────┐       ┌─────────────┐
  │  ARCHITECT  │ ────► │ IMPLEMENTER │ ────► │  REVIEWER   │
  └─────────────┘       └─────────────┘       └─────────────┘
        │                     │                     │
        ▼                     ▼                     ▼
  ┌─────────────┐       ┌─────────────┐       ┌─────────────┐
  │ 1. Define   │       │ 2. Write    │       │ 3. Verify   │
  │    specs &  │       │    tests    │       │    tests    │
  │    test     │       │    first,   │       │    pass &   │
  │    criteria │       │    then     │       │    coverage │
  │             │       │    code     │       │    is good  │
  └─────────────┘       └─────────────┘       └─────────────┘

  The pipeline encourages Test-Driven Development:
  • Architect defines acceptance criteria and test scenarios
  • Implementer writes tests first, then code to make them pass
  • Reviewer verifies coverage and validates test correctness


                         ── Parallel Pattern ──

                        ┌─────────────────────┐
                        │    Multiple Tasks   │
                        └─────────────────────┘
                                  │
                 ┌────────────────┼────────────────┐
                 │                │                │
                 ▼                ▼                ▼
           ┌──────────┐    ┌──────────┐    ┌──────────┐
           │  Task 1  │    │  Task 2  │    │  Task 3  │
           └──────────┘    └──────────┘    └──────────┘
                 │                │                │
                 └────────────────┼────────────────┘
                                  ▼
                        ┌─────────────────────┐
                        │  ParallelResult     │
                        │  ─────────────────  │
                        │  • All results      │
                        │  • Success rate     │
                        │  • Total cost       │
                        └─────────────────────┘
                                  │
                          (optional)
                                  ▼
                        ┌─────────────────────┐
                        │     REVIEWER        │
                        │  ─────────────────  │
                        │  "Merge results,    │
                        │   resolve conflicts │
                        │   between outputs"  │
                        └─────────────────────┘


                        ── Sequential Pattern ──

  ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
  │  Task 1  │ ──► │  Task 2  │ ──► │  Task 3  │ ──► │  Task 4  │
  └──────────┘     └──────────┘     └──────────┘     └──────────┘
       │                │                │                │
       ▼                ▼                ▼                ▼
   Result 1 ──────► Context ──────► Context ──────► Context
                   for Task 2      for Task 3      for Task 4

  • Each task receives context from previous results
  • Can stop on first failure (configurable)
  • Useful for dependent tasks that build on each other


                          ── Router Pattern ──

                        ┌─────────────────────┐
                        │   Incoming Task     │
                        └─────────────────────┘
                                  │
                                  ▼
                        ┌─────────────────────┐
                        │   Route Matching    │
                        │   ───────────────   │
                        │   • By difficulty   │
                        │   • By keywords     │
                        │   • Custom logic    │
                        └─────────────────────┘
                                  │
         ┌────────────────────────┼────────────────────────┐
         │                        │                        │
         ▼                        ▼                        ▼
  ┌──────────────┐       ┌──────────────┐       ┌──────────────┐
  │ "bug", "fix" │       │  :complex    │       │   default    │
  │      ▼       │       │      ▼       │       │      ▼       │
  │ IMPLEMENTER  │       │   PIPELINE   │       │    AUTO      │
  └──────────────┘       └──────────────┘       └──────────────┘

  • Routes tasks to different handlers based on conditions
  • Built-in routing by difficulty tier or keywords
  • Supports custom routing logic
  • Falls back to default when no routes match
```

### Handling Conflicts in Parallel Results

When running tasks in parallel, each task produces independent results. For tasks that might produce conflicting outputs (e.g., multiple agents implementing the same feature), you can use the **Reviewer agent** to merge and resolve conflicts:

```ruby
# Run parallel implementations
parallel = OrchestraAI.conductor.parallel(
  OrchestraAI::Tasks::Definition.new(description: "Implement auth with JWT"),
  OrchestraAI::Tasks::Definition.new(description: "Implement auth with sessions")
)
results = parallel.execute

# Use reviewer to analyse and merge
merge_task = OrchestraAI::Tasks::Definition.new(
  description: "Compare these implementations and create a unified solution",
  context: results.successful.map(&:to_context)
)
merged = OrchestraAI.reviewer.execute(merge_task)
```

The Reviewer agent is specifically designed to:
- Identify conflicts between different implementations
- Prioritize approaches based on requirements
- Synthesize the best parts of each solution
- Produce a unified, coherent output

## Features

- **Multi-Provider Support**: OpenAI, Anthropic (Claude), and Google (Gemini)
- **Role-Based Agents**: Architect, Implementer, and Reviewer agents with specialized prompts
- **Task Difficulty Scoring**: Automatic complexity assessment to select appropriate models
- **Execution Patterns**: Sequential, Parallel, Pipeline, and Router patterns
- **Cost Optimisation**: Automatically routes simple tasks to cheaper models
- **Reliability**: Built-in retry policies and circuit breakers
- **Testing Support**: Mock providers and Minitest assertions

## Installation

Install the gem:

```bash
gem install orchestra_ai
```

That's it! You can now use the `orchestra` CLI directly from your terminal — no Ruby code required.

### For Ruby projects

Add to your Gemfile:

```ruby
gem 'orchestra_ai'
```

Then run:

```bash
bundle install
```

## Configuration

Set your API keys as environment variables:

```bash
export ANTHROPIC_API_KEY="your-key"
export OPENAI_API_KEY="your-key"
export GOOGLE_API_KEY="your-key"
```

You only need to configure the providers you want to use.

## Quick Start (CLI)

The fastest way to use OrchestraAI — no Ruby code needed:

```bash
# Execute a task (auto-selects the best agent and model)
orchestra execute "Build a user authentication system"

# Use a specific agent
orchestra execute --agent architect "Design a caching strategy"
orchestra execute --agent implementer "Write a function to parse JSON"
orchestra execute --agent reviewer "Review this code for security issues"

# Use pipeline pattern (Architect -> Implementer -> Reviewer)
orchestra execute --pattern pipeline "Refactor this module"

# Stream output in real-time
orchestra execute --stream "Explain microservices architecture"

# Score task difficulty (see which model would be used)
orchestra score "Implement distributed locking"

# List available models with pricing
orchestra models

# Show current configuration
orchestra config

# Show version
orchestra version
```

## Ruby API

For programmatic usage in Ruby applications:

### Configuration

```ruby
OrchestraAI.configure do |c|
  c.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
  c.openai_api_key = ENV["OPENAI_API_KEY"]
  c.google_api_key = ENV["GOOGLE_API_KEY"]
end
```

### Basic Execution

```ruby
task = OrchestraAI::Tasks::Definition.new(
  description: "Write a REST API for user authentication"
)

result = OrchestraAI.execute(task)
puts result.content
```

### Using Specific Agents

```ruby
# Use the architect for planning
plan = OrchestraAI.architect.execute(task)

# Use the implementer for coding
code = OrchestraAI.implementer.execute(task)

# Use the reviewer for code review
review = OrchestraAI.reviewer.execute(task)
```

### Pipeline Execution

```ruby
pipeline = OrchestraAI.conductor.pipeline do |p|
  p.stage(:plan) { |t, _| OrchestraAI.architect.execute(t) }
  p.stage(:implement) { |t, ctx|
    impl_task = t.dup_with(context: [ctx[:plan].to_context])
    OrchestraAI.implementer.execute(impl_task)
  }
  p.stage(:review) { |t, ctx|
    OrchestraAI.reviewer.execute(t.dup_with(context: [ctx[:implement].to_context]))
  }
end

result = pipeline.execute(task)
puts result[:review].content
```

### Parallel Execution

```ruby
tasks = [
  OrchestraAI::Tasks::Definition.new(description: "Task 1"),
  OrchestraAI::Tasks::Definition.new(description: "Task 2"),
  OrchestraAI::Tasks::Definition.new(description: "Task 3")
]

parallel = OrchestraAI.conductor.parallel(*tasks)
results = parallel.execute

puts "Success rate: #{results.success_rate * 100}%"
```

### Intelligent Routing

```ruby
router = OrchestraAI.conductor.router do |r|
  r.route_by_keywords("bug", "fix") { |t| OrchestraAI.implementer.execute(t) }
  r.route_by_keywords("design", "architect") { |t| OrchestraAI.architect.execute(t) }
  r.route_by_difficulty(:complex) { |t|
    OrchestraAI::Orchestration::Patterns::Pipeline.standard.execute(t)
  }
  r.default { |t| OrchestraAI.execute(t, pattern: :auto) }
end

result = router.execute(task)
```

## Model Selection by Difficulty

| Role | Simple (< 0.33) | Moderate (0.33-0.66) | Complex (> 0.66) |
|------|-----------------|----------------------|------------------|
| Architect | gemini-2.0-flash | gpt-5-codex | claude-opus-4 |
| Implementer | gemini-2.0-flash | gemini-2.0-flash | gpt-5-codex |
| Reviewer | gemini-2.0-flash | gpt-5-codex | claude-opus-4 |

## Testing

Use the mock provider for testing:

```ruby
require "minitest/autorun"
require "orchestra_ai"

class MyTest < Minitest::Test
  def setup
    @mock_provider = OrchestraAI::Testing::MockProvider.new(responses: ["Mocked response"])
  end

  def test_handles_ai_responses
    result = @mock_provider.complete([{ role: "user", content: "Test" }])

    assert_equal "Mocked response", result[:content]
    assert @mock_provider.received_message?("Test")
  end
end
```

Include custom assertions:

```ruby
require "orchestra_ai/testing/matchers"

class TaskExecutionTest < Minitest::Test
  def test_uses_correct_agent
    task = OrchestraAI::Tasks::Definition.new(description: "Design a system")
    result = OrchestraAI.architect.execute(task)

    assert_used_agent :architect, result
    assert_successful result
  end

  def test_task_classification
    simple_task = OrchestraAI::Tasks::Definition.new(description: "Fix typo")
    complex_task = OrchestraAI::Tasks::Definition.new(description: "Design distributed system")

    assert_classified_as :simple, simple_task
    refute_classified_as :simple, complex_task
  end
end
```

Run tests with:

```bash
bundle exec rake test
```

## License

MIT License. See [LICENSE](LICENSE) for details.

