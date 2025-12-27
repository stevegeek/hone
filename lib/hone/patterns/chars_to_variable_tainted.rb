# frozen_string_literal: true

module Hone
  module Patterns
    # Approach 2: Taint tracking version of CharsToVariable
    #
    # Same detection as CharsToVariable but using the TaintTrackingBase
    # infrastructure. This allows comparison of both approaches.
    #
    # Advantages over simple approach:
    # - Handles variable aliasing (x = chars; y = x; y[0])
    # - Handles instance variables (@chars = str.chars)
    # - Cleaner separation of concerns
    # - Easier to extend for other patterns
    #
    # @example Detects aliased usage
    #   chars = str.chars
    #   x = chars        # Taint propagates to x
    #   x[0]             # Still flagged!
    #
    class CharsToVariableTainted < TaintTrackingBase
      self.pattern_id = :chars_to_variable_tainted
      self.optimization_type = :allocation

      protected

      # Define what creates a taint: .chars calls
      def taint_from_call(call_node)
        return nil unless call_node.name == :chars
        return nil if call_node.arguments&.arguments&.any?

        source_receiver = call_node.receiver
        return nil unless source_receiver

        {
          type: :chars_array,
          source: source_receiver,
          source_code: source_receiver.slice,
          origin_line: call_node.location.start_line,
          metadata: {}
        }
      end

      # Check for problematic uses of tainted variables
      def check_tainted_usage(call_node, var_name, taint_info)
        return unless taint_info.type == :chars_array

        source = taint_info.source_code
        method_name = call_node.name

        case method_name
        when :[]
          report_indexing(call_node, source)
        when :length, :size
          report_length(call_node, source)
        when :each
          report_each(call_node, source) if block_attached?(call_node)
        when :first
          report_first(call_node, source)
        when :last
          report_last(call_node, source)
        when :include?
          report_include(call_node, source)
        when :map
          report_map(call_node, source, var_name) if block_attached?(call_node)
        when :join
          # join actually needs the array - mark this usage as "necessary"
          # In a more sophisticated version, we'd track this and not report
          # the assignment if there's at least one necessary usage
          nil
        when :reverse, :sort, :shuffle, :sample
          # These operations need the array
          nil
        end
      end

      private

      def report_indexing(node, source)
        add_finding(
          node,
          message: "Use `#{source}[...]` directly instead of `.chars` variable indexing",
          speedup: "Avoids allocating array of all characters"
        )
      end

      def report_length(node, source)
        add_finding(
          node,
          message: "Use `#{source}.length` directly instead of `.chars.length`",
          speedup: "Avoids allocating array of all characters"
        )
      end

      def report_each(node, source)
        add_finding(
          node,
          message: "Use `#{source}.each_char { }` instead of `.chars.each { }`",
          speedup: "~1.4x faster, no intermediate array"
        )
      end

      def report_first(node, source)
        add_finding(
          node,
          message: "Use `#{source}[0]` instead of `.chars.first`",
          speedup: "Avoids allocating array of all characters"
        )
      end

      def report_last(node, source)
        add_finding(
          node,
          message: "Use `#{source}[-1]` instead of `.chars.last`",
          speedup: "Avoids allocating array of all characters"
        )
      end

      def report_include(node, source)
        add_finding(
          node,
          message: "Use `#{source}.include?(...)` directly on string",
          speedup: "String#include? works without array allocation"
        )
      end

      def report_map(node, source, var_name)
        add_finding(
          node,
          message: "Consider `#{source}.each_char.map { }` instead of `#{var_name}.map { }`",
          speedup: "Uses lazy enumerator, may reduce allocations"
        )
      end
    end
  end
end
