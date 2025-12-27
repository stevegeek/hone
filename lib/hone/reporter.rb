# frozen_string_literal: true

module Hone
  class Reporter
    include Formatters::Filterable

    # ANSI color codes
    COLORS = {
      reset: "\e[0m",
      bold: "\e[1m",
      dim: "\e[2m",
      red: "\e[31m",
      green: "\e[32m",
      yellow: "\e[33m",
      cyan: "\e[36m",
      white: "\e[37m",
      bright_red: "\e[91m",
      gray: "\e[90m"
    }.freeze

    # Priority display configuration
    PRIORITY_CONFIG = {
      hot_cpu: {label: "High impact", color: %i[bold bright_red], metric: :cpu},
      hot_alloc: {label: "High impact", color: %i[bold red], metric: :alloc},
      jit_unfriendly: {label: "JIT issue", color: %i[bold yellow], metric: nil},
      warm: {label: "Moderate", color: [:yellow], metric: nil},
      cold: {label: "Low", color: %i[dim gray], metric: nil},
      unknown: {label: "Unknown", color: [:dim], metric: nil}
    }.freeze

    SEPARATOR_WIDTH = 72
    CONTEXT_LINES = 2

    def initialize(findings, options = {})
      @findings = findings
      @show_cold = options.fetch(:show_cold, false)
      @quiet = options.fetch(:quiet, false)
      @verbose = options.fetch(:verbose, false)
      @color = options.fetch(:color, $stdout.tty? && !ENV["NO_COLOR"])
      @profile_path = options[:profile_path]
      @file_path = options[:file_path]
      @hot_threshold = options.fetch(:hot_threshold, Correlator::HOT_THRESHOLD)
      @warm_threshold = options.fetch(:warm_threshold, Correlator::WARM_THRESHOLD)
      @source_cache = {}
    end

    def format
      output = []
      output << header unless @quiet
      output << findings_output
      output << summary
      output.flatten.compact.join("\n")
    end

    alias_method :report, :format

    private

    def header
      lines = []
      lines << colorize("Hone v#{VERSION}", :bold)
      lines << ""

      context_parts = []
      context_parts << "Analyzing #{@file_path}" if @file_path
      context_parts << "with profile: #{@profile_path}" if @profile_path

      lines << context_parts.join(" ") unless context_parts.empty?
      lines
    end

    def findings_output
      visible_findings.map { |finding| format_finding(finding) }
    end

    def visible_findings
      filter_cold(@findings, show_cold: @show_cold)
    end

    def format_finding(finding)
      if @quiet
        format_finding_quiet(finding)
      elsif @verbose
        format_finding_verbose(finding)
      else
        format_finding_default(finding)
      end
    end

    # Quiet mode: single line per finding
    def format_finding_quiet(finding)
      location = "#{finding.file}:#{finding.line}"
      metric = format_primary_metric(finding)
      original = finding.code&.strip&.split("\n")&.first&.strip || ""
      suggestion = SuggestionGenerator.generate(finding.pattern_id, original)

      if suggestion && suggestion != original
        # Shorten for display
        original_short = truncate(original, 30)
        suggestion_short = truncate(suggestion, 30)
        transform = "#{original_short} → #{suggestion_short}"
      else
        transform = truncate(original, 40)
      end

      "#{location}  #{metric}  #{transform}"
    end

    # Default mode: balanced detail with source context
    def format_finding_default(finding)
      lines = []
      lines << separator
      lines << ""

      # Location and method
      location = colorize("#{finding.file}:#{finding.line}", :cyan)
      method_info = finding.method_name ? " in `#{finding.method_name}`" : ""
      lines << "#{location}#{method_info}"

      # Metrics with impact label
      lines << format_metrics_line(finding)
      lines << ""

      # Source context with line numbers
      lines.concat(format_source_context(finding))
      lines << ""

      # Fix suggestion
      lines.concat(format_fix_suggestion(finding))
      lines << ""

      lines
    end

    # Verbose mode: full detail with extended explanation
    def format_finding_verbose(finding)
      lines = []
      lines << separator
      lines << ""

      # Location, method, and pattern info
      location = colorize("#{finding.file}:#{finding.line}", :cyan)
      method_info = finding.method_name ? " in `#{finding.method_name}`" : ""
      lines << "#{location}#{method_info}"

      # Metrics
      lines << format_metrics_line(finding)

      # Pattern metadata
      pattern_info = "Pattern: #{finding.pattern_id}"
      pattern_info += "  Type: #{finding.optimization_type}" if finding.optimization_type
      lines << colorize(pattern_info, :dim)
      lines << ""

      # Source context (more lines in verbose)
      lines.concat(format_source_context(finding, context_lines: 3))
      lines << ""

      # Fix suggestion with full explanation
      lines.concat(format_fix_suggestion(finding, include_explanation: true))
      lines << ""

      lines
    end

    def format_metrics_line(finding)
      priority = finding.priority || :unknown
      config = PRIORITY_CONFIG[priority]

      parts = []

      # Primary metric
      if finding.alloc_percent && finding.alloc_percent > 0
        parts << "#{format_percent(finding.alloc_percent)} of allocations"
      end
      if finding.cpu_percent && finding.cpu_percent > 0
        parts << "#{format_percent(finding.cpu_percent)} of CPU"
      end

      metric_str = parts.any? ? parts.join(", ") : nil

      # Impact label
      impact = colorize_multi(config[:label], config[:color])

      if metric_str
        "#{metric_str} — #{impact}"
      else
        impact
      end
    end

    def format_source_context(finding, context_lines: CONTEXT_LINES)
      lines = []
      source_lines = read_source_lines(finding.file)
      return lines if source_lines.empty?

      target_line = finding.line
      start_line = [target_line - context_lines, 1].max
      end_line = [target_line + context_lines, source_lines.size].min

      # Calculate line number width for alignment
      width = end_line.to_s.length

      (start_line..end_line).each do |line_num|
        line_content = source_lines[line_num - 1] || ""
        line_content = line_content.chomp

        if line_num == target_line
          # Highlight the target line
          prefix = colorize("#{line_num.to_s.rjust(width)} │ ", :dim)
          lines << "#{prefix}#{line_content}"

          # Add caret marker
          if finding.column && finding.column > 0
            caret_padding = " " * (width + 3 + finding.column)
            code_length = [finding.code&.split("\n")&.first&.length || 5, 3].max
            carets = colorize("^" * [code_length, 40].min, :bright_red)
            lines << "#{caret_padding}#{carets}"
          end
        else
          prefix = colorize("#{line_num.to_s.rjust(width)} │ ", :dim)
          lines << colorize("#{prefix}#{line_content}", :dim)
        end
      end

      lines
    end

    def format_fix_suggestion(finding, include_explanation: false)
      lines = []
      original_code = finding.code&.strip&.split("\n")&.first&.strip || ""
      suggested_code = SuggestionGenerator.generate(finding.pattern_id, original_code)

      if suggested_code && suggested_code != original_code
        lines << "#{colorize("Fix:", :bold)} #{colorize(suggested_code, :green)}"
      end

      # Explanation (merged Why/Speedup into single line)
      explanation = finding.message
      if explanation
        lines << "     #{explanation}"
      end

      lines
    end

    def format_primary_metric(finding)
      if finding.alloc_percent && finding.alloc_percent >= 1
        "#{format_percent(finding.alloc_percent)} alloc"
      elsif finding.cpu_percent && finding.cpu_percent >= 1
        "#{format_percent(finding.cpu_percent)} CPU"
      elsif finding.alloc_percent
        "#{format_percent(finding.alloc_percent)} alloc"
      elsif finding.cpu_percent
        "#{format_percent(finding.cpu_percent)} CPU"
      else
        "?"
      end
    end

    def summary
      stats = calculate_stats
      build_summary_output(stats)
    end

    def calculate_stats
      counts = @findings.map { |f| f.priority || :unknown }.tally
      {
        total: @findings.size,
        hot_cpu: counts[:hot_cpu] || 0,
        hot_alloc: counts[:hot_alloc] || 0,
        jit_unfriendly: counts[:jit_unfriendly] || 0,
        warm: counts[:warm] || 0,
        cold: counts[:cold] || 0,
        unknown: counts[:unknown] || 0
      }
    end

    def build_summary_output(stats)
      lines = []
      lines << separator
      lines << ""

      total = stats[:total]
      high_impact = stats[:hot_cpu] + stats[:hot_alloc]

      if @quiet
        parts = []
        parts << "#{high_impact} high" if high_impact > 0
        parts << "#{stats[:jit_unfriendly]} jit" if stats[:jit_unfriendly] > 0
        parts << "#{stats[:warm]} moderate" if stats[:warm] > 0
        parts << "#{stats[:cold]} low" if stats[:cold] > 0
        lines << "#{total} findings: #{parts.join(", ")}"
        return lines
      end

      lines << colorize("Summary: #{total} #{(total == 1) ? "finding" : "findings"}", :bold)
      lines << ""

      if high_impact > 0
        label = colorize_multi("#{high_impact} high impact", PRIORITY_CONFIG[:hot_cpu][:color])
        arrow = colorize("← fix these first", :bold)
        lines << "  #{label}  (>#{@hot_threshold.to_i}% of CPU or allocations)  #{arrow}"
      end

      if stats[:jit_unfriendly] > 0
        label = colorize_multi("#{stats[:jit_unfriendly]} JIT issues", PRIORITY_CONFIG[:jit_unfriendly][:color])
        lines << "  #{label}  (may hurt YJIT optimization)"
      end

      if stats[:warm] > 0
        label = colorize_multi("#{stats[:warm]} moderate", PRIORITY_CONFIG[:warm][:color])
        lines << "  #{label}  (#{@warm_threshold.to_i}-#{@hot_threshold.to_i}%)"
      end

      if stats[:cold] > 0
        label = colorize_multi("#{stats[:cold]} low", PRIORITY_CONFIG[:cold][:color])
        hint = @show_cold ? "" : "  (use --show-cold to display)"
        lines << "  #{label}  (<#{@warm_threshold.to_i}%)#{hint}"
      end

      if stats[:unknown] > 0
        label = colorize_multi("#{stats[:unknown]} unknown", PRIORITY_CONFIG[:unknown][:color])
        lines << "  #{label}  (no profile data)"
      end

      if @verbose
        lines << ""
        lines << colorize("Percentages show share of total profiled CPU time or allocations.", :dim)
      end

      lines << ""
      lines
    end

    def read_source_lines(file_path)
      return @source_cache[file_path] if @source_cache.key?(file_path)

      @source_cache[file_path] = if File.exist?(file_path)
        File.readlines(file_path)
      else
        []
      end
    end

    def separator
      colorize("─" * SEPARATOR_WIDTH, :dim)
    end

    def truncate(str, max_length)
      return str if str.length <= max_length
      "#{str[0, max_length - 3]}..."
    end

    def colorize(text, *colors)
      return text unless @color

      codes = colors.flatten.map { |c| COLORS[c] }.compact.join
      "#{codes}#{text}#{COLORS[:reset]}"
    end

    def colorize_multi(text, colors)
      colorize(text, *colors)
    end

    def format_percent(value)
      return "0%" if value.nil? || value == 0
      value < 0.1 ? "<0.1%" : "#{value.round(1)}%"
    end
  end
end
