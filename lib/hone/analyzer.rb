# frozen_string_literal: true

module Hone
  # Orchestrates the full analysis pipeline:
  # Scanner -> MethodMap -> Profiler -> Correlator -> Reporter
  #
  # @example Basic usage (static analysis only)
  #   analyzer = Hone::Analyzer.new("app.rb")
  #   result = analyzer.run
  #   puts result.output
  #
  # @example With profile correlation
  #   analyzer = Hone::Analyzer.new("app.rb", profile: "profile.json")
  #   result = analyzer.run
  #
  # @example Directory analysis
  #   analyzer = Hone::Analyzer.new("lib/", format: :json)
  #   result = analyzer.run
  #
  class Analyzer
    # Default directory for cached profile files
    PROFILE_DIR = "tmp/hone"

    # Result of analysis containing findings, output, and exit code
    Result = Data.define(:findings, :output, :exit_code)

    # @param path [String] File or directory to analyze
    # @param profile [String, nil] Path to StackProf JSON profile
    # @param memory_profile [String, nil] Path to MemoryProfiler JSON profile
    # @param format [Symbol] Output format: :text, :json, :github
    # @param color [Boolean, nil] Force color output (nil = auto-detect)
    # @param quiet [Boolean] Minimal output
    # @param verbose [Boolean] Extended output with pattern details
    # @param top [Integer, nil] Show only top N findings
    # @param hot_only [Boolean] Only show HOT findings
    # @param show_cold [Boolean] Include COLD findings
    # @param fail_on [Symbol] Exit non-zero for: :hot, :warm, :any, :none
    # @param diff [String, nil] Git ref to compare against for changed files
    # @param baseline [String, nil] Path to baseline JSON file to suppress findings
    # @param rails [Boolean] Enable Rails-specific analysis
    def initialize(path, profile: nil, memory_profile: nil, format: :text, color: nil, quiet: false, verbose: false,
      top: nil, hot_only: false, show_cold: false, fail_on: :hot, diff: nil, baseline: nil, rails: false)
      @path = path
      @profile_path = profile || auto_detect_profile(:cpu)
      @memory_profile_path = memory_profile || auto_detect_profile(:memory)
      @format = format.to_sym
      @color = color
      @quiet = quiet
      @verbose = verbose
      @top = top
      @hot_only = hot_only
      @show_cold = show_cold
      @fail_on = fail_on.to_sym
      @diff = diff
      @baseline = baseline
      @rails = rails
    end

    # Run the analysis pipeline
    # @return [Result] Analysis result with findings, output, and exit code
    def run
      validate_input!

      # Step 1: Scan for patterns
      findings = scan_path

      # Step 2: Build method map for correlation
      method_map = build_method_map

      # Step 3: Load profile data (if available)
      profiles = load_profiles

      # Step 4: Correlate findings with profile
      correlator = Correlator.new(
        method_map: method_map,
        cpu_profile: profiles[:cpu],
        memory_profile: profiles[:memory]
      )
      correlated = correlator.correlate(findings)

      # Step 5: Apply filtering
      filtered = apply_filters(correlated)

      # Step 6: Generate output
      output = generate_output(filtered)

      # Step 7: Calculate exit code
      exit_code = calculate_exit_code(filtered)

      Result.new(findings: filtered, output: output, exit_code: exit_code)
    rescue Error => e
      Result.new(findings: [], output: "Error: #{e.message}", exit_code: ExitCodes::ERROR)
    rescue => e
      Result.new(findings: [], output: "Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}", exit_code: ExitCodes::ERROR)
    end

    private

    def validate_input!
      raise Error, "Path not found: #{@path}" unless File.exist?(@path)

      raise Error, "Profile not found: #{@profile_path}" if @profile_path && !File.exist?(@profile_path)

      raise Error, "Baseline not found: #{@baseline}" if @baseline && !File.exist?(@baseline)

      raise Error, "Memory profile not found: #{@memory_profile_path}" if @memory_profile_path && !File.exist?(@memory_profile_path)

      unless %i[text json github sarif junit tsv].include?(@format)
        raise Error, "Invalid format: #{@format}. Use text, json, github, sarif, junit, or tsv."
      end

      return if %i[hot warm any none].include?(@fail_on)

      raise Error, "Invalid fail_on: #{@fail_on}. Use hot, warm, any, or none."
    end

    def scan_path
      scanner = Scanner.new(rails: @rails)

      if File.directory?(@path)
        scanner.scan_directory(@path)
      else
        scanner.scan_file(@path)
      end
    end

    def build_method_map
      method_map = MethodMap.new

      if File.directory?(@path)
        Dir.glob(File.join(@path, "**/*.rb")).each do |file|
          method_map.add_file(file)
        end
      else
        method_map.add_file(@path)
      end

      method_map
    end

    def load_profiles
      {
        cpu: load_cpu_profile,
        memory: load_memory_profile
      }
    end

    def load_cpu_profile
      Profilers::Factory.create(@profile_path)
    end

    def load_memory_profile
      return nil unless @memory_profile_path

      Profilers::MemoryProfiler.new(@memory_profile_path)
    end

    def apply_filters(findings)
      FindingFilter.new(findings, filter_options).apply
    end

    def filter_options
      {
        diff: @diff,
        baseline: @baseline,
        hot_only: @hot_only,
        show_cold: @show_cold,
        profile_path: @profile_path,
        top: @top
      }
    end

    def generate_output(findings)
      case @format
      when :json
        Formatters::JSON.new(findings, reporter_options).format
      when :github
        Formatters::GitHub.new(findings, reporter_options).format
      when :sarif
        Formatters::SARIF.new(findings, reporter_options).format
      when :junit
        Formatters::JUnit.new(findings, reporter_options).format
      when :tsv
        Formatters::TSV.new(findings, reporter_options).format
      else
        Reporter.new(findings, reporter_options).report
      end
    end

    def reporter_options
      {
        show_cold: @show_cold,
        quiet: @quiet,
        verbose: @verbose,
        color: determine_color,
        profile_path: @profile_path,
        memory_profile_path: @memory_profile_path,
        file_path: @path,
        mode: @profile_path ? "correlated" : "static"
      }
    end

    def determine_color
      return @color unless @color.nil?

      # Auto-detect: color if TTY and NO_COLOR not set
      $stdout.tty? && !ENV["NO_COLOR"]
    end

    def calculate_exit_code(findings)
      return ExitCodes::SUCCESS if findings.empty?

      case @fail_on
      when :none
        ExitCodes::SUCCESS
      when :any
        ExitCodes::HOT
      when :hot
        has_hot = findings.any? { |f| f.priority == :hot }
        has_hot ? ExitCodes::HOT : ExitCodes::SUCCESS
      when :warm
        has_hot = findings.any? { |f| f.priority == :hot }
        has_warm = findings.any? { |f| f.priority == :warm }

        if has_hot
          ExitCodes::HOT
        elsif has_warm
          ExitCodes::WARM
        else
          ExitCodes::SUCCESS
        end
      else
        ExitCodes::SUCCESS
      end
    end

    def auto_detect_profile(type)
      filename = case type
      when :cpu then "cpu_profile.json"
      when :memory then "memory_profile.json"
      end

      path = File.join(PROFILE_DIR, filename)

      if File.exist?(path)
        metadata_path = File.join(PROFILE_DIR, "metadata.json")
        if File.exist?(metadata_path)
          metadata = JSON.parse(File.read(metadata_path))
          generated = metadata["generated_at"]
          warn "Using cached #{type} profile from #{path} (generated: #{generated})"
        else
          warn "Using cached #{type} profile from #{path}"
        end
        path
      end
    end
  end
end
