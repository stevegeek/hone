# frozen_string_literal: true

module Hone
  module Formatters
    module Filterable
      PRIORITY_LABELS = {
        hot_cpu: "HOT-CPU",
        hot_alloc: "HOT-ALLOC",
        jit_unfriendly: "JIT-UNFRIENDLY",
        warm: "WARM",
        cold: "COLD",
        unknown: "?"
      }.freeze

      def filter_cold(findings, show_cold:)
        return findings if show_cold

        findings.reject { |f| f.priority == :cold }
      end

      def priority_label(priority)
        PRIORITY_LABELS.fetch(priority, priority.to_s.upcase)
      end

      def format_percent(value)
        return "" if value.nil?
        "%.1f%%" % value
      end
    end
  end
end
