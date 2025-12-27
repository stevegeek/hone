# Hone Examples

These examples demonstrate patterns that Hone detects. Run them to see Hone in action.

## Quick Test

```bash
# From the hone directory
hone analyze examples/

# Or analyze a specific file
hone analyze examples/allocation_patterns.rb
```

## With Profiling

```bash
# Run the benchmark with profiling
cd examples
ruby benchmark.rb

# Analyze with the generated profile
hone analyze . --profile tmp/profile.json --memory-profile tmp/memory.json
```

## Files

- `cpu_patterns.rb` - Method call overhead, loop inefficiencies
- `allocation_patterns.rb` - Intermediate arrays, string allocations
- `jit_patterns.rb` - YJIT optimization blockers
- `benchmark.rb` - Runnable benchmark that generates profiles
