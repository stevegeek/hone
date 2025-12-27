# frozen_string_literal: true

require "json"

module Hone
  module Formatters
    # SARIF (Static Analysis Results Interchange Format) formatter for GitHub Code Scanning.
    #
    # SARIF is a standard format for static analysis tools, supported by GitHub Code Scanning
    # and other security/code quality platforms.
    #
    # @see https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html
    #
    # @example Usage
    #   formatter = Hone::Formatters::SARIF.new(findings)
    #   puts formatter.format
    class SARIF < Base
      SARIF_VERSION = "2.1.0"
      SARIF_SCHEMA = "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json"

      # Maps Hone priority levels to SARIF severity levels.
      # - error: A serious problem that should be addressed immediately
      # - warning: A potential problem that should be reviewed
      # - note: Informational finding
      PRIORITY_TO_LEVEL = {
        hot_cpu: "error",
        hot_alloc: "error",
        jit_unfriendly: "warning",
        warm: "warning",
        cold: "note",
        unknown: "note"
      }.freeze

      def format
        ::JSON.pretty_generate(build_sarif)
      end

      private

      def build_sarif
        {
          "$schema" => SARIF_SCHEMA,
          "version" => SARIF_VERSION,
          "runs" => [build_run]
        }
      end

      def build_run
        {
          "tool" => build_tool,
          "results" => build_results
        }
      end

      def build_tool
        {
          "driver" => {
            "name" => "Hone",
            "version" => Hone::VERSION,
            "informationUri" => "https://github.com/your-org/hone",
            "rules" => build_rules
          }
        }
      end

      def build_rules
        # Collect unique pattern IDs from findings to build rule definitions
        unique_patterns = @findings.map(&:pattern_id).uniq

        unique_patterns.map { |pattern_id| build_rule(pattern_id) }
      end

      def build_rule(pattern_id)
        {
          "id" => pattern_id.to_s,
          "name" => humanize_pattern_id(pattern_id),
          "shortDescription" => {
            "text" => "#{humanize_pattern_id(pattern_id)} optimization opportunity"
          },
          "helpUri" => "https://github.com/your-org/hone##{pattern_id}"
        }
      end

      def humanize_pattern_id(pattern_id)
        pattern_id.to_s.split("_").map(&:capitalize).join(" ")
      end

      def build_results
        @findings.map { |finding| build_result(finding) }
      end

      def build_result(finding)
        result = {
          "ruleId" => finding.pattern_id.to_s,
          "level" => sarif_level(finding),
          "message" => {
            "text" => build_message_text(finding)
          },
          "locations" => [build_location(finding)]
        }

        # Add optional properties if available
        result["partialFingerprints"] = build_fingerprints(finding) if finding.method_name

        result
      end

      def sarif_level(finding)
        priority = finding.priority || :unknown
        PRIORITY_TO_LEVEL.fetch(priority, "note")
      end

      def build_message_text(finding)
        parts = [finding.message]

        if finding.cpu_percent
          parts << "CPU: %.1f%%" % finding.cpu_percent
        end

        if finding.alloc_percent
          parts << "Allocations: %.1f%%" % finding.alloc_percent
        end

        if finding.speedup
          parts << "Expected speedup: #{finding.speedup}"
        end

        parts.join(" | ")
      end

      def build_location(finding)
        location = {
          "physicalLocation" => {
            "artifactLocation" => {
              "uri" => finding.file
            },
            "region" => build_region(finding)
          }
        }

        # Add logical location (method name) if available
        if finding.method_name
          location["logicalLocations"] = [
            {
              "name" => finding.method_name,
              "kind" => "function"
            }
          ]
        end

        location
      end

      def build_region(finding)
        region = {
          "startLine" => finding.line
        }

        region["startColumn"] = finding.column if finding.column

        # Include the source code snippet if available
        if finding.code
          region["snippet"] = {
            "text" => finding.code
          }
        end

        region
      end

      def build_fingerprints(finding)
        # Partial fingerprints help GitHub track results across runs
        {
          "methodName" => finding.method_name
        }
      end
    end
  end
end
