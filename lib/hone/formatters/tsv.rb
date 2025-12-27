# frozen_string_literal: true

module Hone
  module Formatters
    class TSV < Base
      HEADERS = %w[priority cpu_percent alloc_percent file line pattern_id message method_name].freeze
      COLUMN_SEPARATOR = "\t"

      def format
        lines = [header_row]
        lines.concat(filtered_findings.map { |finding| format_row(finding) })
        lines.join("\n")
      end

      private

      def header_row
        HEADERS.join(COLUMN_SEPARATOR)
      end

      def format_row(finding)
        [
          (finding.priority || "").to_s,
          format_percent(finding.cpu_percent),
          format_percent(finding.alloc_percent),
          finding.file.to_s,
          finding.line.to_s,
          finding.pattern_id.to_s,
          escape_field(finding.message.to_s),
          finding.method_name.to_s
        ].join(COLUMN_SEPARATOR)
      end

      def format_percent(value)
        return "" if value.nil?

        value.to_s
      end

      def escape_field(value)
        # Escape tabs and newlines for TSV compatibility
        value
          .gsub("\t", "\\t")
          .gsub("\n", "\\n")
          .gsub("\r", "\\r")
      end
    end
  end
end
