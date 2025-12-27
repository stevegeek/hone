# frozen_string_literal: true

require "thor"

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
        baseline: options[:baseline]
      )

      result = analyzer.run

      puts result.output unless result.output.empty?

      exit result.exit_code
    end

    default_task :analyze
  end
end
