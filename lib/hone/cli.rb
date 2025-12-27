# frozen_string_literal: true

require "thor"
require_relative "harness"
require_relative "harness_generator"
require_relative "harness_runner"

module Hone
  # Command-line interface for Hone Ruby performance analyzer.
  #
  # @example Basic usage
  #   hone analyze FILE                    # Static analysis (no profile)
  #   hone analyze FILE --profile FILE     # Correlation mode (prioritized)
  #   hone analyze DIR                     # Analyze directory
  #
  # @example Output control
  #   hone analyze FILE --format json      # JSON output
  #   hone analyze FILE --format github    # GitHub Actions annotations
  #   hone analyze FILE --quiet            # Minimal output
  #   hone analyze FILE --no-color         # Disable colors
  #
  # @example Filtering
  #   hone analyze FILE --top=10           # Show only top 10 findings
  #   hone analyze FILE --hot-only         # Only HOT findings
  #   hone analyze FILE --show-cold        # Include COLD findings
  #
  # @example CI integration
  #   hone analyze FILE --fail-on hot      # Exit 1 for HOT (default)
  #   hone analyze FILE --fail-on warm     # Exit 2 for WARM, 1 for HOT
  #   hone analyze FILE --fail-on any      # Exit 1 for any finding
  #   hone analyze FILE --fail-on none     # Always exit 0
  #
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc "version", "Print version"
    def version
      puts "Hone v#{Hone::VERSION}"
    end
    map %w[-v --version] => :version

    desc "analyze PATH", "Analyze Ruby file(s) for optimization opportunities"
    long_desc <<~DESC
      Analyze Ruby source files for performance optimization opportunities.

      When run with --profile, findings are correlated with runtime profiling data
      to prioritize optimizations that will have the greatest impact. Findings are
      categorized as HOT (>5% CPU), WARM (1-5% CPU), or COLD (<1% CPU).

      Without --profile, all findings are reported without prioritization.

      Exit codes:
        0 - No findings, or only COLD findings
        1 - HOT findings exist
        2 - WARM findings exist (no HOT)
        3 - Error occurred

      Examples:
        hone analyze app.rb
        hone analyze lib/ --profile profile.json
        hone analyze . --format github --fail-on warm
    DESC
    option :profile,
      type: :string,
      desc: "StackProf JSON profile for correlation",
      aliases: "-p"
    option :memory_profile,
      type: :string,
      desc: "MemoryProfiler JSON for allocation correlation",
      aliases: "-m"
    option :format,
      type: :string,
      default: "text",
      desc: "Output format: text, json, github, sarif, junit, tsv",
      aliases: "-f"
    option :color,
      type: :boolean,
      default: nil,
      desc: "Force color output (default: auto-detect TTY)"
    option :quiet,
      type: :boolean,
      default: false,
      desc: "Minimal output (one line per finding)",
      aliases: "-q"
    option :top,
      type: :numeric,
      desc: "Show only top N findings"
    option :hot_only,
      type: :boolean,
      default: false,
      desc: "Only show HOT findings"
    option :show_cold,
      type: :boolean,
      default: false,
      desc: "Include COLD findings in output"
    option :fail_on,
      type: :string,
      default: "hot",
      desc: "Exit non-zero for: hot (default), warm, any, none"
    option :diff,
      type: :string,
      desc: "Only analyze files changed since BASE ref"
    option :baseline,
      type: :string,
      desc: "Suppress findings in baseline JSON file"
    option :rails,
      type: :boolean,
      default: false,
      desc: "Include Rails/ActiveSupport-specific optimizations"
    def analyze(path)
      analyzer = Analyzer.new(
        path,
        profile: options[:profile],
        memory_profile: options[:memory_profile],
        format: options[:format],
        color: options[:color],
        quiet: options[:quiet],
        top: options[:top],
        hot_only: options[:hot_only],
        show_cold: options[:show_cold],
        fail_on: options[:fail_on],
        diff: options[:diff],
        baseline: options[:baseline],
        rails: options[:rails]
      )

      result = analyzer.run

      puts result.output unless result.output.empty?

      exit result.exit_code
    end

    desc "init COMPONENT", "Initialize Hone components"
    long_desc <<~DESC
      Initialize Hone components in your project.

      Components:
        harness - Generate a performance harness template

      Examples:
        hone init harness        # Generate basic Ruby harness
        hone init harness --rails  # Generate Rails-specific harness
    DESC
    option :rails,
      type: :boolean,
      default: false,
      desc: "Generate Rails-specific harness template"
    def init(component)
      case component
      when "harness"
        generator = HarnessGenerator.new(rails: options[:rails])
        generator.generate
      else
        puts "Unknown component: #{component}"
        puts "Available components: harness"
        exit 1
      end
    end

    desc "profile", "Run harness and generate performance profiles"
    long_desc <<~DESC
      Run the performance harness and generate CPU (and optionally memory) profiles.

      The harness file should define setup, exercise, and teardown blocks.
      Profiles are saved to tmp/hone/ by default.

      Examples:
        hone profile                    # Run default harness
        hone profile --memory           # Include memory profiling
        hone profile --analyze          # Profile then analyze
        hone profile --harness custom.rb  # Use custom harness file
    DESC
    option :harness,
      type: :string,
      default: ".hone/harness.rb",
      desc: "Path to harness file"
    option :profiler,
      type: :string,
      enum: %w[auto stackprof vernier],
      default: "auto",
      desc: "CPU profiler to use"
    option :memory,
      type: :boolean,
      default: false,
      desc: "Include memory profiling"
    option :warmup,
      type: :numeric,
      default: 10,
      desc: "Warmup iterations before profiling"
    option :output,
      type: :string,
      default: "tmp/hone",
      desc: "Output directory for profiles"
    option :analyze,
      type: :boolean,
      default: false,
      desc: "Run analysis after profiling"
    def profile
      unless File.exist?(options[:harness])
        puts "Harness file not found: #{options[:harness]}"
        puts "Run 'hone init harness' to generate a template."
        exit 1
      end

      profiler_opt = (options[:profiler] == "auto") ? nil : options[:profiler].to_sym

      runner = HarnessRunner.new(
        options[:harness],
        profiler: profiler_opt,
        memory: options[:memory],
        warmup: options[:warmup],
        output_dir: options[:output]
      )

      puts "Loading harness from #{options[:harness]}..."
      puts "Warmup: #{options[:warmup]} iterations"
      puts "Profiler: #{profiler_opt || "auto-detect"}"
      puts

      profiles = runner.run

      puts "Profiles generated:"
      puts "  CPU:    #{profiles[:cpu]}"
      puts "  Memory: #{profiles[:memory]}" if profiles[:memory]
      puts

      if options[:analyze]
        puts "Running analysis..."
        invoke :analyze, ["."], profile: profiles[:cpu], memory_profile: profiles[:memory]
      else
        puts "Run analysis with:"
        puts "  hone analyze . --profile #{profiles[:cpu]}"
      end
    end

    default_task :analyze
  end
end
