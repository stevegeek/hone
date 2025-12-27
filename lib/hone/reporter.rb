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
      white: "\e[37m",
      bright_red: "\e[91m",
      gray: "\e[90m"
    }.freeze

    # Priority display configuration
    PRIORITY_STYLES = {
      hot_cpu: {label: "HOT-CPU", color: %i[bold bright_red]},
      hot_alloc: {label: "HOT-ALLOC", color: %i[bold red]},
      jit_unfriendly: {label: "JIT-UNFRIENDLY", color: %i[bold yellow]},
      warm: {label: "WARM", color: [:yellow]},
      cold: {label: "COLD", color: %i[dim gray]},
      unknown: {label: "?", color: [:white]}
    }.freeze

    # Width in characters for horizontal separator lines in report output.
    # Chosen to fit comfortably in standard 80-column terminals with margins.
    SEPARATOR_WIDTH = 72

    def initialize(findings, options = {})
      @findings = findings
      @show_cold = options.fetch(:show_cold, false)
      @quiet = options.fetch(:quiet, false)
      @color = options.fetch(:color, $stdout.tty? && !ENV["NO_COLOR"])
      @profile_path = options[:profile_path]
      @file_path = options[:file_path]
      @hot_threshold = options.fetch(:hot_threshold, Correlator::HOT_THRESHOLD)
      @warm_threshold = options.fetch(:warm_threshold, Correlator::WARM_THRESHOLD)
    end

    def format
      output = []
      output << header
      output << separator
      output << findings_output
      output << separator
      output << summary
      output.flatten.compact.join("\n")
    end

    # Backwards compatibility alias
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
      lines << "" unless context_parts.empty?
      lines
    end

    def separator
      colorize("\u2500" * SEPARATOR_WIDTH, :dim)
    end

    def findings_output
      visible_findings.map { |finding| format_finding(finding) }
    end

    def visible_findings
      filter_cold(@findings, show_cold: @show_cold)
    end

    def hidden_cold_count
      @findings.count { |f| f.priority == :cold }
    end

    def format_finding(finding)
      if @quiet
        format_finding_quiet(finding)
      else
        format_finding_full(finding)
      end
    end

    def format_finding_quiet(finding)
      priority = finding.priority || :unknown
      style = PRIORITY_STYLES[priority]
      label = colorize_multi("[#{style[:label]}]", style[:color])

      location = "#{finding.file}:#{finding.line}"
      method_info = finding.method_name ? " `#{finding.method_name}`" : ""

      cpu_info = finding.cpu_percent ? "#{format_percent(finding.cpu_percent)} CPU" : nil
      alloc_info = finding.alloc_percent ? "#{format_percent(finding.alloc_percent)} alloc" : nil
      metrics = [cpu_info, alloc_info].compact.join(", ")
      metrics_display = metrics.empty? ? "" : " \u2014 #{metrics}"

      "#{label} #{location}#{method_info}#{metrics_display}"
    end

    def format_finding_full(finding)
      lines = []
      lines << ""

      # Header line: [HOT-CPU] file:line `method` - XX% CPU, YY% alloc
      priority = finding.priority || :unknown
      style = PRIORITY_STYLES[priority]
      label = colorize_multi("[#{style[:label]}]", style[:color])

      location = colorize("#{finding.file}:#{finding.line}", :bold)
      method_info = finding.method_name ? " `#{finding.method_name}`" : ""

      cpu_info = finding.cpu_percent ? "#{format_percent(finding.cpu_percent)} CPU" : nil
      alloc_info = finding.alloc_percent ? "#{format_percent(finding.alloc_percent)} alloc" : nil
      metrics = [cpu_info, alloc_info].compact.join(", ")
      metrics_display = metrics.empty? ? "" : " \u2014 #{colorize(metrics, :bold)}"

      lines << "#{label} #{location}#{method_info}#{metrics_display}"
      lines << ""

      # Code diff (before/after)
      if finding.code
        lines.concat(format_code_diff(finding))
        lines << ""
      end

      # Why explanation
      lines << "  #{colorize("Why:", :dim)} #{finding.message}"

      lines << "  #{colorize("Speedup:", :dim)} #{finding.speedup}" if finding.speedup

      lines << ""
      lines
    end

    def format_code_diff(finding)
      lines = []
      original_code = finding.code.strip

      # Generate suggestion based on pattern
      suggested_code = SuggestionGenerator.generate(finding.pattern_id, original_code)

      if suggested_code && suggested_code != original_code
        lines << "  #{colorize("- #{original_code}", :red)}"
        lines << "  #{colorize("+ #{suggested_code}", :green)}"
      else
        lines << "  #{colorize(original_code, :dim)}"
      end

      lines
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
      lines << ""

      total = stats[:total]
      lines << colorize("Summary: #{total} optimization #{(total == 1) ? "opportunity" : "opportunities"}", :bold)
      lines << ""

      hot_threshold = @hot_threshold
      warm_threshold = @warm_threshold

      if stats[:hot_cpu] > 0
        label = colorize_multi("HOT-CPU", PRIORITY_STYLES[:hot_cpu][:color])
        arrow = colorize("\u2190 fix these first", :bold)
        lines << "  #{label}        #{stats[:hot_cpu]} high CPU impact  (>#{hot_threshold.to_i}% CPU)   #{arrow}"
      end

      if stats[:hot_alloc] > 0
        label = colorize_multi("HOT-ALLOC", PRIORITY_STYLES[:hot_alloc][:color])
        arrow = colorize("\u2190 fix these first", :bold)
        lines << "  #{label}      #{stats[:hot_alloc]} high allocation impact  (>#{hot_threshold.to_i}% alloc)   #{arrow}"
      end

      if stats[:jit_unfriendly] > 0
        label = colorize_multi("JIT-UNFRIENDLY", PRIORITY_STYLES[:jit_unfriendly][:color])
        lines << "  #{label} #{stats[:jit_unfriendly]} JIT optimization patterns"
      end

      if stats[:warm] > 0
        warm_label = colorize_multi("WARM", PRIORITY_STYLES[:warm][:color])
        lines << "  #{warm_label}           #{stats[:warm]} moderate impact  (#{warm_threshold.to_i}-#{hot_threshold.to_i}%)"
      end

      if stats[:cold] > 0
        cold_label = colorize_multi("COLD", PRIORITY_STYLES[:cold][:color])
        show_cold_hint = @show_cold ? "" : "   (use --show-cold to display)"
        lines << "  #{cold_label}           #{stats[:cold]} low impact  (<#{warm_threshold.to_i}%)#{show_cold_hint}"
      end

      if stats[:unknown] > 0
        unknown_label = colorize_multi("?", PRIORITY_STYLES[:unknown][:color])
        lines << "  #{unknown_label}              #{stats[:unknown]} uncorrelated  (no profile data)"
      end

      lines << ""
      lines
    end

    def colorize(text, *colors)
      return text unless @color

      codes = colors.flatten.map { |c| COLORS[c] }.compact.join
      "#{codes}#{text}#{COLORS[:reset]}"
    end

    def colorize_multi(text, colors)
      colorize(text, *colors)
    end
  end
end
