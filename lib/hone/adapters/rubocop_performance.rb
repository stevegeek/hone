# frozen_string_literal: true

require "open3"
require "json"

module Hone
  module Adapters
    class RubocopPerformance < Base
      def findings
        return [] unless rubocop_available? && rubocop_performance_available?

        parse_output(run_rubocop)
      rescue JSON::ParserError => e
        warn "[Hone::Adapters::RubocopPerformance] Failed to parse RuboCop output: #{e.message}"
        []
      rescue => e
        warn "[Hone::Adapters::RubocopPerformance] #{e.message}"
        []
      end

      private

      def source_name
        :rubocop
      end

      def rubocop_available?
        _, _, status = Open3.capture3("which", "rubocop")
        status.success?
      end

      def rubocop_performance_available?
        stdout, _, status = Open3.capture3("gem", "list", "rubocop-performance")
        status.success? && stdout.include?("rubocop-performance")
      end

      def run_rubocop
        stdout, _stderr, _status = Open3.capture3(
          "rubocop",
          "--only", "Performance",
          "--format", "json",
          @file_path
        )
        stdout
      end

      def parse_output(output)
        return [] if output.nil? || output.strip.empty?

        data = JSON.parse(output)
        files = data["files"] || []

        files.flat_map do |file_data|
          offenses = file_data["offenses"] || []
          offenses.map do |offense|
            build_finding(
              line: offense.dig("location", "line") || 0,
              message: offense["message"],
              pattern_id: offense["cop_name"]&.to_sym || :unknown,
              optimization_type: severity_to_optimization_type(offense["severity"]),
              code: extract_code(offense)
            )
          end
        end
      end

      def severity_to_optimization_type(severity)
        case severity
        when "error", "fatal"
          :cpu
        when "warning"
          :cpu
        when "convention", "refactor"
          :allocation
        else
          :cpu
        end
      end

      def extract_code(offense)
        offense.dig("location", "source")
      end
    end
  end
end
