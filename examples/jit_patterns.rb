# frozen_string_literal: true

# rubocop:disable all
# standardrb:disable all

# JIT optimization patterns that Hone detects
# NOTE: This file intentionally contains anti-patterns for testing
# These patterns can prevent YJIT from optimizing effectively

class JitPatterns
  # Dynamic instance_variable_set
  def set_field(name, value)
    instance_variable_set("@#{name}", value)  # Hone: Causes shape transitions
  end

  # Dynamic instance_variable_get
  def get_field(name)
    instance_variable_get("@#{name}")  # Hone: Consider explicit accessors
  end

  # Lazy ivar initialization outside initialize
  def cached_value
    @cached ||= expensive_computation  # Hone: Initialize in constructor
  end

  # defined? check for ivar
  def ensure_loaded
    @data = load_data unless defined?(@data)  # Hone: Use nil check or initialize
  end

  private

  def expensive_computation
    sleep(0.001)
    42
  end

  def load_data
    []
  end
end

# RECOMMENDED: Initialize all ivars in constructor for stable object shape.
# This allows YJIT to optimize method dispatch because the object's
# memory layout is consistent from creation.
class StableShape
  def initialize
    @cached = nil
    @data = nil
  end

  def cached_value
    @cached ||= expensive_computation
  end

  def data
    @data ||= load_data
  end

  private

  def expensive_computation
    42
  end

  def load_data
    []
  end
end
