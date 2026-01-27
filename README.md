# OrchestraAI

A Ruby gem for orchestrating multiple AI agents (OpenAI, Gemini, Claude) with role-based execution, parallel processing, task difficulty scoring, and cost optimization.

## Features

- **Multi-Provider Support**: OpenAI, Anthropic (Claude), and Google (Gemini)
- **Role-Based Agents**: Architect, Implementer, and Reviewer agents with specialized prompts
- **Task Difficulty Scoring**: Automatic complexity assessment to select appropriate models
- **Execution Patterns**: Sequential, Parallel, Pipeline, and Router patterns
- **Cost Optimization**: Automatically routes simple tasks to cheaper models
- **Reliability**: Built-in retry policies and circuit breakers
- **Testing Support**: Mock providers and RSpec matchers

## Installation

Add to your Gemfile:

```ruby
gem 'orchestra_ai'
```

Then run:

```bash
bundle install
```

Or install directly:

```bash
gem install orchestra_ai
```

## Configuration

```ruby
OrchestraAI.configure do |c|
  c.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
  c.openai_api_key = ENV["OPENAI_API_KEY"]
  c.google_api_key = ENV["GOOGLE_API_KEY"]
end
```

## Usage

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

## CLI

```bash
# Execute a task
orchestra execute "Build a user authentication system"

# Use specific pattern
orchestra execute --pattern pipeline "Refactor this module"

# Use specific agent
orchestra execute --agent architect "Design a caching strategy"

# Score task difficulty
orchestra score "Implement distributed locking"

# List available models
orchestra models

# Show configuration
orchestra config
```

## Model Selection by Difficulty

| Role | Simple (< 0.33) | Moderate (0.33-0.66) | Complex (> 0.66) |
|------|-----------------|----------------------|------------------|
| Architect | claude-3-5-haiku | claude-sonnet-4 | claude-opus-4 |
| Implementer | gemini-2.0-flash | gemini-2.5-pro | claude-sonnet-4 |
| Reviewer | gpt-4o-mini | gpt-4o | claude-opus-4 |

## Testing

Use the mock provider for testing:

```ruby
RSpec.describe MyClass do
  let(:mock_provider) { OrchestraAI::Testing::MockProvider.new(responses: ["Mocked response"]) }

  it "handles AI responses" do
    result = mock_provider.complete([{ role: "user", content: "Test" }])
    expect(result[:content]).to eq("Mocked response")
    expect(mock_provider.received_message?("Test")).to be true
  end
end
```

Include custom matchers:

```ruby
require "orchestra_ai/testing/matchers"

RSpec.describe "Task execution" do
  include OrchestraAI::Testing::Matchers

  it "uses the correct agent" do
    result = OrchestraAI.architect.execute(task)
    expect(result).to have_used_agent(:architect)
    expect(result).to be_successful
  end
end
```

## License

MIT License. See [LICENSE](LICENSE) for details.
