# frozen_string_literal: true

require "fileutils"
require "json"

module Hone
  class HarnessRunner
    PROFILE_DIR = "tmp/hone"

    attr_reader :harness_path, :profiler, :include_memory, :warmup, :output_dir

    def initialize(harness_path, options = {})
      @harness_path = harness_path
      @profiler = options[:profiler] || detect_profiler
      @include_memory = options.fetch(:memory, false)
      @warmup = options.fetch(:warmup, 10)
      @output_dir = options.fetch(:output_dir, PROFILE_DIR)
    end

    def run
      harness = Harness.load(@harness_path)

      unless harness.valid?
        raise Hone::Error, "Harness must define an exercise block"
      end

      FileUtils.mkdir_p(@output_dir)

      # Setup phase (not profiled)
      harness.run_setup

      # Warmup phase (not profiled, lets JIT optimize)
      @warmup.times { harness.run_exercise }

      # Profile CPU
      cpu_path = profile_cpu(harness)

      # Profile memory (if requested)
      memory_path = @include_memory ? profile_memory(harness) : nil

      # Teardown phase
      harness.run_teardown

      # Write metadata
      write_metadata(cpu_path, memory_path, harness.iterations)

      {cpu: cpu_path, memory: memory_path}
    end

    private

    def profile_cpu(harness)
      path = File.join(@output_dir, "cpu_profile.json")

      case @profiler
      when :stackprof
        profile_with_stackprof(harness, path)
      when :vernier
        profile_with_vernier(harness, path)
      else
        raise Hone::Error, "Unknown profiler: #{@profiler}"
      end

      path
    end

    def profile_with_stackprof(harness, path)
      require "stackprof"
      # Run profiling and capture the result (don't let StackProf write Marshal format)
      result = StackProf.run(mode: :cpu, raw: true, interval: 1000) do
        harness.iterations.times { harness.run_exercise }
      end
      # Convert to JSON format that Hone can parse
      File.write(path, stackprof_to_json(result))
    end

    def stackprof_to_json(data)
      # Convert StackProf result to JSON with string keys
      json_data = {
        "mode" => data[:mode].to_s,
        "samples" => data[:samples],
        "frames" => {}
      }

      data[:frames].each do |address, frame|
        json_data["frames"][address.to_s] = {
          "name" => frame[:name],
          "file" => frame[:file],
          "line" => frame[:line],
          "samples" => frame[:samples] || 0,
          "total_samples" => frame[:total_samples] || 0
        }
      end

      JSON.pretty_generate(json_data)
    end

    def profile_with_vernier(harness, path)
      require "vernier"
      Vernier.profile(out: path) do
        harness.iterations.times { harness.run_exercise }
      end
    end

    def profile_memory(harness)
      path = File.join(@output_dir, "memory_profile.json")
      require "memory_profiler"

      report = MemoryProfiler.report do
        harness.run_exercise
      end

      File.write(path, memory_report_to_json(report))
      path
    end

    def memory_report_to_json(report)
      # Convert MemoryProfiler report to JSON format
      data = {
        total_allocated: report.total_allocated,
        total_retained: report.total_retained,
        allocated_memory_by_location: report.allocated_memory_by_location.map do |stat|
          {location: stat[:data], bytes: stat[:count]}
        end,
        retained_memory_by_location: report.retained_memory_by_location.map do |stat|
          {location: stat[:data], bytes: stat[:count]}
        end
      }
      JSON.pretty_generate(data)
    end

    def write_metadata(cpu_path, memory_path, iterations)
      metadata = {
        generated_at: Time.now.iso8601,
        ruby_version: RUBY_VERSION,
        yjit_enabled: defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?,
        profiler: @profiler.to_s,
        warmup_iterations: @warmup,
        profile_iterations: iterations,
        cpu_profile: cpu_path,
        memory_profile: memory_path
      }

      File.write(File.join(@output_dir, "metadata.json"), JSON.pretty_generate(metadata))
    end

    def detect_profiler
      # Prefer Vernier if available (modern, better output)

      require "vernier"
      :vernier
    rescue LoadError
      begin
        require "stackprof"
        :stackprof
      rescue LoadError
        raise Hone::Error, "No profiler available. Install stackprof or vernier gem."
      end
    end
  end
end
