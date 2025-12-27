# Hone Examples

Example files with intentional anti-patterns for testing Hone.

## Quick Test

```bash
cd examples

# Static analysis only
hone analyze .

# With profiling (recommended)
hone profile --memory --analyze
```

## Files

- `cpu_patterns.rb` - Method call overhead, loop inefficiencies
- `allocation_patterns.rb` - Intermediate arrays, string allocations
- `jit_patterns.rb` - YJIT optimization blockers
- `.hone/harness.rb` - Profiling harness for these examples
