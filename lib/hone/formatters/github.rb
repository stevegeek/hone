# frozen_string_literal: true

module Hone
  module Formatters
    class GitHub < Base
      PRIORITY_TO_LEVEL = {
        hot_cpu: "error",
        hot_alloc: "error",
        jit_unfriendly: "warning",
        warm: "notice",
        cold: "notice",
        unknown: "notice"
      }.freeze

      def format
        filtered_findings.map { |finding| format_annotation(finding) }.join("\n")
      end

      private

      def format_annotation(finding)
        level = annotation_level(finding)
        file = finding.file
        line = finding.line
        title = build_title(finding)
        message = escape_message(finding.message)

        "::#{level} file=#{file},line=#{line},title=#{title}::#{message}"
      end

      def annotation_level(finding)
        priority = finding.priority || :unknown
        PRIORITY_TO_LEVEL.fetch(priority, "notice")
      end

      def build_title(finding)
        heat = priority_label(finding.priority || :unknown)

        cpu_info = finding.cpu_percent ? "#{format_percent(finding.cpu_percent)} CPU" : nil
        alloc_info = finding.alloc_percent ? "#{format_percent(finding.alloc_percent)} alloc" : nil
        metrics = [cpu_info, alloc_info].compact.join(", ")

        metrics.empty? ? heat : "#{heat} #{metrics}"
      end

      def escape_message(message)
        # GitHub Actions annotation messages need specific escaping:
        # - %0A for newlines
        # - %25 for %
        # - %0D for carriage returns
        message
          .gsub("%", "%25")
          .gsub("\r", "%0D")
          .gsub("\n", "%0A")
      end

      def priority_label(priority)
        case priority
        when :hot_cpu then "HOT-CPU"
        when :hot_alloc then "HOT-ALLOC"
        when :jit_unfriendly then "JIT-UNFRIENDLY"
        else priority.to_s.upcase
        end
      end

      def format_percent(percent)
        "%.1f%%" % percent
      end
    end
  end
end
