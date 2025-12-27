# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: range.include?(x) -> range.cover?(x)
    #
    # include? iterates the range to check membership.
    # cover? just checks if value is between bounds (O(1)).
    #
    # Note: Semantics differ for non-numeric ranges. cover? checks bounds only,
    # include? checks actual membership. For numeric ranges they're equivalent.
    class RangeInclude < Base
      self.pattern_id = :range_include
      self.optimization_type = :cpu

      def visit_call_node(node)
        super

        # Look for: .include?(x) on a range literal
        return unless node.name == :include?
        return unless node.arguments&.arguments&.size == 1

        receiver = node.receiver
        return unless receiver.is_a?(Prism::RangeNode)

        add_finding(
          node,
          message: "Use `.cover?` instead of `.include?` on ranges for O(1) bounds check",
          speedup: "O(n) iteration to O(1) comparison (for numeric ranges)"
        )
      end
    end
  end
end
