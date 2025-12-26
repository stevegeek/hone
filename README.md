# Hone

A Ruby gem for finding performance optimization opportunities by combining static AST analysis with runtime profiling data.

**Status: Early development / proof-of-concept**

## The Problem

Static analysis tools like RuboCop Performance flag optimization patterns equally, regardless of whether that code is actually a bottleneck. Profilers like Vernier show you where time is spent, but don't suggest what to fix. Developers are left manually correlating between tools.

## The Idea

Hone bridges static analysis and runtime profiling:

1. **Static analysis** (via Prism) detects optimization patterns in your code
2. **Runtime profiling** identifies actual CPU and memory hotspots
3. **Correlation** prioritizes patterns that are in hot code paths
4. **JIT awareness** understands which patterns affect YJIT optimization

This means you get recommendations ranked by actual impact, not just pattern matching.

## Example Output

Patterns in hot methods get prioritized. Cold code patterns are deprioritized—fixing them won't move the needle.

```
=== STEP 3: HONE CUSTOM MATCHERS (Prism-based) ===

Hone found 5 issues:
  Line 24 [chars_map_ord]: Use `.codepoints` instead of `.chars.map(&:ord)`
  Line 32 [map_select_chain]: Use `.filter_map { }` instead of `.map { }.select { }`
  Line 52 [positive_predicate]: Use `> 0` instead of `.positive?` in hot paths
  Line 64 [kernel_loop]: Use `while true` instead of `loop { }` in hot paths
  Line 89 [slice_with_length]: Use endless range `[1..]` instead of `[1, str.length]`

=== STEP 5: CORRELATION ===

PRIORITIZED RECOMMENDATIONS:

 1. [🔥 HOT] [FASTERER]
    Line 41: Using each_with_index is slower than while loop.
    Method: SqidsPatterns#sum_with_index (18.5% of runtime)

 2. [🔥 HOT] [HONE:map_select_chain]
    Line 32: Use `.filter_map { }` instead of `.map { }.select { }`
    Method: SqidsPatterns#filter_numbers (3.93% of runtime)

 3. [❄️  COLD] [HONE:chars_map_ord]
    Line 24: Use `.codepoints` instead of `.chars.map(&:ord)`
    Method: SqidsPatterns#decode_chars (0.0% of runtime)

```

Different optimizations target different dimensions—a method can be CPU-cold but allocation-hot:

```
=== STEP 4: DUAL-DIMENSION CORRELATION ===

PRIORITIZED RECOMMENDATIONS:

 1. [🔥 ALLOC-HOT] [HONE:chars_map_ord] (ALLOCATION)
    Line 57: Use `.codepoints` instead of `.chars.map(&:ord)`
    Method: DualHotspotExample#process_text_chars
    CPU: 0.15% | Allocations: 99.4%

 2. [🔥 CPU-HOT] [HONE:positive_predicate] (CPU)
    Line 30: Use `> 0` instead of `.positive?` in hot paths
    Method: DualHotspotExample#compute_score
    CPU: 1.06% | Allocations: 0.0%

 3. [❄️  COLD] [HONE:map_select_chain] (ALLOCATION)
    Line 67: Use `.filter_map { }` instead of `.map { }.select { }`
    Method: DualHotspotExample#filter_and_transform
    CPU: 0.75% | Allocations: 0.4%

KEY INSIGHT:
  • ALLOCATION patterns → correlate with allocation hotspots
  • CPU patterns → correlate with CPU hotspots
  A method might be cold in CPU but hot in allocations!
```

JIT-aware patterns understand YJIT optimization impact:

```
=== STEP 2: CPU PROFILING ===

CPU hotspots (top 5):
    3.39%  DynamicIvarRecord#get_field
     1.6%  EagerIvarRecord#ensure_name
     1.6%  StableShapeRecord#process

=== STEP 3: ALLOCATION PROFILING ===

Allocation hotspots (top 5):
   16.67%  DynamicIvarRecord#set_field (300000 objects)
   11.11%  DynamicIvarRecord#get_field (200000 objects)
   11.11%  EagerIvarRecord#ensure_name (199990 objects)

=== STEP 5: TRIPLE-DIMENSION CORRELATION ===

PRIORITIZED RECOMMENDATIONS:

 1. [🔥 JIT-HOT] [HONE:dynamic_ivar_get]
    Dynamic instance_variable_get suggests ivars used as key-value store...
    Method: DynamicIvarRecord#get_field
    CPU: 3.39% | Alloc: 11.11%

 2. [🔥 JIT-HOT] [HONE:lazy_ivar]
    Lazy ivar initialization (||=) outside initialize causes shape tra...
    Method: EagerIvarRecord#ensure_name
    CPU: 1.6% | Alloc: 11.11%

 3. [❄️  COLD] [HONE:lazy_ivar]
    Lazy ivar initialization (||=) outside initialize causes shape tra...
    Method: LazyIvarRecord#cached_value
    CPU: 0.2% | Alloc: 0.0%
```

## Running the Experiments

```bash
cd experiments
bundle install
bundle exec ruby correlate_advanced.rb
bundle exec ruby correlate_dual.rb
bundle exec ruby correlate_triple.rb
```
