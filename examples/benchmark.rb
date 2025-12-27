#!/usr/bin/env ruby
# frozen_string_literal: true

# Benchmark that exercises the example patterns
# Generates CPU and memory profiles for use with Hone

require "json"
require "fileutils"
require_relative "cpu_patterns"
require_relative "allocation_patterns"
require_relative "jit_patterns"

ITERATIONS = 1000

def run_benchmark
  cpu = CpuPatterns.new
  alloc = AllocationPatterns.new
  jit = JitPatterns.new

  data = (1..100).to_a
  str = "hello world" * 10

  ITERATIONS.times do
    # CPU patterns
    cpu.check_positive(42)
    cpu.count_up
    cpu.sum_with_index(data)
    cpu.tail(str)
    cpu.replace_spaces(str)
    cpu.match_pattern(["abc", "123", "def"])

    # Allocation patterns
    alloc.char_codes(str)
    alloc.transform_and_filter(data)
    alloc.iterate_chars("test")
    alloc.nested_map([1, 2, 3])
    alloc.total(data)
    alloc.random_element(data)
    alloc.smallest(data)
    alloc.final_element(data)
    alloc.build_string(%w[a b c d e])
    alloc.char_at(str, 5)

    # JIT patterns
    jit.set_field("test", 123)
    jit.get_field("test")
    jit.cached_value
  end
end

FileUtils.mkdir_p("tmp")

puts "Running benchmark (#{ITERATIONS} iterations)..."

# CPU profiling
begin
  require "stackprof"
  result = StackProf.run(mode: :cpu, raw: true, interval: 100) do
    run_benchmark
  end

  # Convert StackProf result to JSON format Hone can parse
  json_data = {
    "mode" => result[:mode].to_s,
    "samples" => result[:samples],
    "frames" => {}
  }
  result[:frames].each do |addr, frame|
    json_data["frames"][addr.to_s] = {
      "name" => frame[:name],
      "file" => frame[:file],
      "line" => frame[:line],
      "samples" => frame[:samples] || 0,
      "total_samples" => frame[:total_samples] || 0
    }
  end
  File.write("tmp/profile.json", JSON.pretty_generate(json_data))
  puts "CPU profile: tmp/profile.json"
rescue LoadError
  puts "stackprof not available (gem install stackprof)"
end

# Memory profiling
begin
  require "memory_profiler"
  report = MemoryProfiler.report { run_benchmark }

  # Convert MemoryProfiler result to JSON format Hone can parse
  memory_data = {
    "total_allocated" => report.total_allocated,
    "total_retained" => report.total_retained,
    "allocated_memory_by_location" => report.allocated_memory_by_location.map do |stat|
      {"location" => stat[:data], "bytes" => stat[:count]}
    end
  }
  File.write("tmp/memory.json", JSON.pretty_generate(memory_data))
  puts "Memory profile: tmp/memory.json"
rescue LoadError
  puts "memory_profiler not available (gem install memory_profiler)"
end

puts "\nRun analysis with:"
puts "  hone analyze . --profile tmp/profile.json --memory-profile tmp/memory.json"
