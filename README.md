# Hone

Find Ruby performance optimizations that actually matter by combining static analysis with runtime profiling.

## Installation

Add to your Gemfile:

```ruby
gem 'hone', group: :development

# Optional: for profiling integration
gem 'stackprof', group: :development
gem 'memory_profiler', group: :development
```

Or install directly:

```bash
gem install hone
```

## Quick Start

```bash
# Try it on the included examples
hone analyze examples/

# Or analyze your own code
hone analyze lib/
```

### With Profiling (Recommended)

For prioritized results, use a harness:

```bash
# Create a harness in your project
hone init harness

# Edit .hone/harness.rb to define your workload, then:
hone profile --analyze
```

Or provide an existing StackProf profile:

```bash
hone analyze lib/ --profile stackprof.json
```

## Output

Findings are prioritized by runtime impact:

```
[HOT] lib/order.rb:45 `calculate_total` - 18.5% CPU

  - amount.positive?
  + amount > 0

  Why: Method call overhead; `> 0` uses optimized fixnum comparison.

[WARM] lib/order.rb:128 `validate_items` - 3.2% CPU

  - items.map { }.select { }
  + items.filter_map { }

  Why: Avoids intermediate array allocation.

[COLD] lib/order.rb:201 `to_json` - 0.1% CPU
  (use --show-cold to display)
```

### Heat Levels

| Level | Threshold | Meaning |
|-------|-----------|---------|
| HOT | >5% CPU or memory | High impact - fix these first |
| WARM | 1-5% | Worth fixing when nearby |
| COLD | <1% | Low priority |

Without profiling data, findings show `[?]` (unknown impact).

## CLI Reference

```bash
# Analysis
hone analyze FILE|DIR                    # Static analysis
hone analyze FILE --profile STACKPROF    # With CPU correlation
hone analyze FILE --memory-profile FILE  # With memory correlation

# Profiling
hone init harness                        # Create .hone/harness.rb template
hone profile                             # Run harness, generate profiles
hone profile --analyze                   # Profile and analyze in one step
hone profile --memory                    # Include memory profiling

# Output control
--format FORMAT      # text, json, github, sarif, junit, tsv
--top N              # Show only top N findings
--hot-only           # Only HOT findings
--show-cold          # Include COLD findings (hidden by default)
--quiet              # One line per finding

# CI integration
--fail-on LEVEL      # Exit non-zero for: hot, warm, any, none
--baseline FILE      # Suppress known findings
```

## Harness

The harness defines a repeatable workload for profiling:

```ruby
# .hone/harness.rb
setup do
  require_relative '../lib/my_gem'
  @data = load_test_data
end

exercise iterations: 100 do
  MyGem.process(@data)
end

teardown do
  cleanup  # optional
end
```

- `setup`: Runs once before profiling (load code, prepare data)
- `exercise`: The code to profile (runs N iterations)
- `teardown`: Cleanup after profiling (optional)

## Patterns

Hone detects 50+ patterns across three categories:

- **CPU**: Method call overhead, loop inefficiencies
- **Allocation**: Intermediate arrays, string allocations
- **JIT**: Dynamic ivars, shape transitions, YJIT blockers

Run `hone patterns` to list all available patterns.

## Requirements

- Ruby 3.1+
- Prism (bundled with Ruby 3.3+, add `gem 'prism'` for earlier versions)
