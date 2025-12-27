# Hone

Find Ruby performance optimizations that actually matter by combining static analysis with runtime profiling.

## Example Output

Findings are prioritized by CPU, memory, and JIT impact:

```
[HOT-ALLOC] lib/sqids.rb:69 `Sqids#decode` — 0.1% CPU, 17.4% alloc

  - id.chars.each { |c| ... }
  + id.each_char { |c| ... }

  Why: Avoids intermediate array allocation
  Speedup: ~1.4x faster, no array allocation

[HOT-ALLOC] lib/sqids.rb:103 `Sqids#shuffle` — 2.7% CPU, 13.7% alloc

  chars[i]

  Why: Use `alphabet[...]` directly instead of `.chars` variable indexing
  Speedup: Avoids allocating array of all characters

[JIT-UNFRIENDLY] lib/record.rb:13 `Record#set_field` — 1.0% CPU, 0.2% alloc

  instance_variable_set("@#{name}", value)

  Why: Dynamic instance_variable_set causes object shape transitions, hurting YJIT
  Speedup: Significant with YJIT (2-3x)

[WARM] lib/util.rb:44 `Util#smallest` — 0.0% CPU, 4.8% alloc

  - arr.sort.first
  + arr.min

  Why: O(n) instead of O(n log n), no intermediate array

[COLD] lib/util.rb:89 — 0.1% alloc
  (use --show-cold to display)
```

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

### About Heat Levels

| Level | Meaning |
|-------|---------|
| HOT | >5% CPU or allocation - fix these first |
| HOT-ALLOC | Low CPU but high allocation impact |
| JIT-UNFRIENDLY | Hurts YJIT optimization |
| WARM | 1-5% impact - worth fixing |
| COLD | <1% impact - low priority |

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

## Acknowledgements

Some pattern detections inspired by:

- [fast-ruby](https://github.com/fastruby/fast-ruby) - Benchmarks for common Ruby idioms
- [fasterer](https://github.com/DamirSvrtan/fasterer) - Static analysis for speed improvements
- [rubocop-performance](https://github.com/rubocop/rubocop-performance) - Performance-focused RuboCop cops
