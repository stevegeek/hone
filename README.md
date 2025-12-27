<p align="center">
  <img src="logo.png" alt="Hone" width="200">
</p>

# Hone

Find Ruby performance optimizations that actually matter by combining static analysis with runtime profiling.

## Example Output

When run with profiling data, findings show their actual runtime impact:

```
Hone v0.1.0

Analyzing lib/sqids.rb with profile: tmp/hone/cpu_profile.json
────────────────────────────────────────────────────────────────────────

lib/sqids.rb:69 in `Sqids#decode`
17.5% of allocations — High impact

67 │
68 │     alphabet_chars = @alphabet.chars
69 │     id.chars.each do |c|
         ^^^^^^^^^^^^^^^^^^^^
70 │       return ret unless alphabet_chars.include?(c)
71 │     end

     Use `id.each_char { ... }` instead of `chars.each` to avoid intermediate array

────────────────────────────────────────────────────────────────────────

lib/sqids.rb:183 in `Sqids#blocked_id?`
13.5% of CPU — High impact

181 │           id.start_with?(word) || id.end_with?(word)
182 │         else
183 │           id.include?(word)
                ^^^^^^^^^^^^^^^^^
184 │         end
185 │       end

     Consider using Set instead of Array#include? for repeated lookups

────────────────────────────────────────────────────────────────────────

lib/sqids.rb:104 in `Sqids#shuffle`
3.1% of CPU — Moderate

102 │     i = 0
103 │     j = chars.length - 1
104 │     while j.positive?
                ^^^^^^^^^^^
105 │       r = ((i * j) + chars[i].ord + chars[j].ord) % chars.length
106 │       chars[i], chars[r] = chars[r], chars[i]

Fix: j > 0
     Use `> 0` instead of `.positive?` to avoid method call overhead

────────────────────────────────────────────────────────────────────────

Summary: 14 findings

  3 high impact  (>5% of CPU or allocations)  ← fix these first
  11 moderate  (1-5%)
```

The percentages show how much CPU time or memory allocation each method used during profiling, helping you focus on fixes that matter.

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

### About Impact Levels

| Level | Meaning |
|-------|---------|
| High impact | >5% CPU or allocation - fix these first |
| JIT issue | Hurts YJIT optimization |
| Moderate | 1-5% impact - worth fixing |
| Low | <1% impact - low priority |

Without profiling data, findings show "Unknown" impact.

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
--hot-only           # Only high impact findings
--show-cold          # Include low impact findings (hidden by default)
--quiet / -q         # One line per finding
--verbose / -V       # Extended output with pattern details

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
