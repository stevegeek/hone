# Hone Pattern Detection Approaches

This document describes the different approaches used for detecting optimization patterns in Ruby code.

## Overview

Hone uses Prism AST visitors to detect code patterns that could be optimized. Patterns range from simple single-node checks to complex data flow analysis.

## Pattern Tiers

| Tier | Complexity | Example |
|------|------------|---------|
| 1: Simple AST | Single node inspection | `.positive?` → `> 0` |
| 2: Context-Aware | Track loop/method scope | String concat in loop |
| 3: Scope-Limited | Track variables within scope | `chars = str.chars; chars[0]` |
| 4: Taint Tracking | Track data flow across assignments | Aliased variable detection |

## Approach Comparison

### Simple Scope Tracking

**File:** `chars_to_variable.rb`

Tracks variable assignments within the current lexical scope. When a variable is assigned from a specific call (e.g., `.chars`), subsequent uses of that variable are checked.

```ruby
def example
  chars = str.chars  # Tracked: chars -> .chars source
  chars[0]           # Detected: inefficient indexing
end
```

**Advantages:**
- Simple implementation
- Low overhead
- Easy to understand and debug

**Limitations:**
- Cannot track variable aliasing (`x = chars; x[0]`)
- Cannot track instance variables across methods
- Scope resets on reassignment

### Taint Tracking

**Files:** `taint_tracking_base.rb`, `chars_to_variable_tainted.rb`

Propagates metadata ("taint") through variable assignments, tracking the origin of data as it flows through the program.

```ruby
def example
  chars = str.chars  # Taint: chars is "chars_array" from str
  x = chars          # Propagate: x inherits taint from chars
  y = x              # Propagate: y inherits taint from x
  y[0]               # Detected: y is tainted with chars_array origin
end
```

**Advantages:**
- Tracks variable aliasing
- Handles instance variables
- Supports chained assignments
- Cleaner separation of concerns

**Limitations:**
- More complex implementation
- Higher memory usage (stores taint info per variable)
- Cannot track across method boundaries (yet)

## Detection Comparison

| Scenario | Simple | Taint |
|----------|--------|-------|
| Direct usage: `chars[0]` | Yes | Yes |
| Aliased: `x = chars; x[0]` | No | Yes |
| Chained: `a = chars; b = a; b[0]` | No | Yes |
| Instance var: `@chars[0]` | No | Yes |
| Cross-method: `def foo; @chars[0]; end` | No | No* |

*Cross-method tracking would require whole-program analysis.

## TaintTrackingBase API

The `TaintTrackingBase` class provides infrastructure for building taint-tracking patterns.

### Subclass Requirements

```ruby
class MyPattern < TaintTrackingBase
  self.pattern_id = :my_pattern
  self.optimization_type = :allocation

  protected

  # Define what creates a taint
  def taint_from_call(call_node)
    return nil unless call_node.name == :dangerous_method

    {
      type: :my_taint_type,
      source: call_node.receiver,
      source_code: call_node.receiver&.slice,
      origin_line: call_node.location.start_line,
      metadata: {}
    }
  end

  # Check for problematic uses of tainted variables
  def check_tainted_usage(call_node, var_name, taint_info)
    return unless taint_info.type == :my_taint_type

    if call_node.name == :problematic_method
      add_finding(call_node, message: "...")
    end
  end
end
```

### Available Methods

```ruby
# Query taint status
get_taint(var_name, scope: :local)   # Returns TaintInfo or nil
tainted?(var_name, scope: :local)    # Returns boolean
all_taints(scope: :local)            # Returns hash of all taints

# Modify taint status (rarely needed in subclasses)
set_taint(var_name, taint_info, scope: :local)
clear_taint(var_name, scope: :local)
```

### TaintInfo Structure

```ruby
TaintInfo = Data.define(
  :type,         # Symbol identifying the taint type
  :source,       # Original AST node (e.g., receiver of .chars)
  :source_code,  # String representation of source
  :origin_line,  # Line number where taint originated
  :metadata      # Hash for pattern-specific data
)
```

## Scope Handling

Both approaches handle Ruby's lexical scoping:

| Construct | Scope Behavior |
|-----------|----------------|
| `def` | New isolated scope |
| `class` / `module` | New isolated scope |
| `lambda` / `->` | New isolated scope |
| `block` | Inherits parent scope (for taint tracking) |

Instance variables use a separate scope (`:instance`) that persists across blocks but resets at class/module boundaries.

## When to Use Each Approach

**Use Simple Scope Tracking when:**
- Pattern only needs direct variable usage
- Performance is critical
- Implementation simplicity is preferred

**Use Taint Tracking when:**
- Pattern involves variable aliasing
- Instance variables need tracking
- Data flow through assignments matters
- Building on existing taint infrastructure

## Future Directions

1. **Cross-method tracking**: Track instance variable taints across method definitions
2. **Escape analysis**: Detect when tainted values escape the current scope
3. **Conditional tracking**: Handle `if` branches that may or may not taint
4. **LLM review layer**: Use language models to filter false positives from complex patterns
