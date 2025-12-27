# frozen_string_literal: true

require "rexml/document"

module Hone
  module Formatters
    class JUnit < Base
      PRIORITY_TO_TYPE = {
        hot_cpu: "failure",
        hot_alloc: "failure",
        jit_unfriendly: "failure",
        warm: "failure",
        cold: "skipped",
        unknown: "failure"
      }.freeze

      def format
        doc = build_document
        output = +""
        formatter = REXML::Formatters::Pretty.new(2)
        formatter.compact = true
        output << %(<?xml version="1.0" encoding="UTF-8"?>\n)
        formatter.write(doc.root, output)
        output
      end

      private

      def build_document
        doc = REXML::Document.new
        testsuites = doc.add_element("testsuites")
        testsuites.add_attribute("name", "Hone")

        findings_by_file = filtered_findings.group_by(&:file)

        total_tests = 0
        total_failures = 0
        total_skipped = 0

        findings_by_file.each do |file, file_findings|
          suite = testsuites.add_element("testsuite")
          suite.add_attribute("name", file)

          suite_failures = 0
          suite_skipped = 0

          file_findings.each do |finding|
            add_testcase(suite, finding, file)

            case result_type(finding)
            when "failure"
              suite_failures += 1
            when "skipped"
              suite_skipped += 1
            end
          end

          suite.add_attribute("tests", file_findings.size.to_s)
          suite.add_attribute("failures", suite_failures.to_s)
          suite.add_attribute("skipped", suite_skipped.to_s)

          total_tests += file_findings.size
          total_failures += suite_failures
          total_skipped += suite_skipped
        end

        testsuites.add_attribute("tests", total_tests.to_s)
        testsuites.add_attribute("failures", total_failures.to_s)
        testsuites.add_attribute("skipped", total_skipped.to_s)

        doc
      end

      def add_testcase(suite, finding, file)
        testcase = suite.add_element("testcase")
        testcase.add_attribute("name", testcase_name(finding))
        testcase.add_attribute("classname", classname_from_file(file))

        case result_type(finding)
        when "failure"
          add_failure_element(testcase, finding)
        when "skipped"
          add_skipped_element(testcase, finding)
        end
      end

      def testcase_name(finding)
        name = finding.pattern_id.to_s
        name += " at line #{finding.line}" if finding.line
        name
      end

      def classname_from_file(file)
        # Convert path like "app/models/order.rb" to "app.models.order"
        file
          .sub(/\.rb\z/, "")
          .tr("/", ".")
      end

      def result_type(finding)
        priority = finding.priority || :unknown
        PRIORITY_TO_TYPE.fetch(priority, "failure")
      end

      def add_failure_element(testcase, finding)
        failure = testcase.add_element("failure")
        failure.add_attribute("message", finding.message)
        failure.add_attribute("type", (finding.priority || :unknown).to_s)
        failure.add_text(failure_details(finding))
      end

      def add_skipped_element(testcase, finding)
        skipped = testcase.add_element("skipped")
        skipped.add_attribute("message", finding.message)
      end

      def failure_details(finding)
        heat = priority_label(finding.priority || :unknown)

        cpu_info = finding.cpu_percent ? "#{format_percent(finding.cpu_percent)} CPU" : nil
        alloc_info = finding.alloc_percent ? "#{format_percent(finding.alloc_percent)} alloc" : nil
        metrics = [cpu_info, alloc_info].compact.join(", ")

        details = if metrics.empty?
          "[#{heat}] #{finding.message}"
        else
          "[#{heat} #{metrics}] #{finding.message}"
        end

        details += "\nCode: #{finding.code}" if finding.code
        details += "\nFile: #{finding.file}:#{finding.line}" if finding.file && finding.line
        details
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
