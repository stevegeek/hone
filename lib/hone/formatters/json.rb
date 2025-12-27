# frozen_string_literal: true

require "json"

module Hone
  module Formatters
    class JSON < Base
      FORMAT_VERSION = "1.0.0"

      def initialize(findings, options = {})
        super
        @profile_path = options[:profile_path]
        @mode = options.fetch(:mode, "correlated")
      end

      def format
        ::JSON.pretty_generate(build_output)
      end

      private

      def build_output
        {
          version: FORMAT_VERSION,
          hone_version: Hone::VERSION,
          analysis: build_analysis,
          summary: build_summary,
          findings: build_findings
        }
      end

      def build_analysis
        {
          mode: @mode,
          profile_source: @profile_path
        }.compact
      end

      def build_summary
        {
          total: @findings.size,
          by_priority: count_by_priority
        }
      end

      def count_by_priority
        @findings.map { |f| f.priority || :unknown }.tally
      end

      def build_findings
        @findings.map { |finding| format_finding(finding) }
      end

      def format_finding(finding)
        {
          heat: (finding.priority || :unknown).to_s,
          cpu_percent: finding.cpu_percent,
          location: {
            path: finding.file,
            line: finding.line,
            column: finding.column
          },
          pattern_id: finding.pattern_id.to_s,
          optimization_type: finding.optimization_type.to_s,
          message: finding.message,
          method_name: finding.method_name,
          code: finding.code,
          speedup: finding.speedup,
          source: finding.source.to_s,
          alloc_percent: finding.alloc_percent
        }.compact
      end
    end
  end
end
