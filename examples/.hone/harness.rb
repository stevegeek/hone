# Hone harness for example patterns
# Run with: hone profile --analyze

setup do
  require_relative "../cpu_patterns"
  require_relative "../allocation_patterns"
  require_relative "../jit_patterns"

  @cpu = CpuPatterns.new
  @alloc = AllocationPatterns.new
  @jit = JitPatterns.new
  @data = (1..100).to_a
  @str = "hello world" * 10
end

exercise iterations: 1000 do
  # CPU patterns
  @cpu.check_positive(42)
  @cpu.count_up
  @cpu.sum_with_index(@data)
  @cpu.tail(@str)
  @cpu.replace_spaces(@str)
  @cpu.match_pattern(["abc", "123", "def"])

  # Allocation patterns
  @alloc.char_codes(@str)
  @alloc.transform_and_filter(@data)
  @alloc.iterate_chars("test")
  @alloc.nested_map([1, 2, 3])
  @alloc.total(@data)
  @alloc.random_element(@data)
  @alloc.smallest(@data)
  @alloc.final_element(@data)
  @alloc.build_string(%w[a b c d e])
  @alloc.char_at(@str, 5)

  # JIT patterns
  @jit.set_field("test", 123)
  @jit.get_field("test")
  @jit.cached_value
end
