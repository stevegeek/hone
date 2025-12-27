# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: hash.values.include?(x) -> hash.value?(x)
    #
    # values.include? creates an intermediate array of values then searches.
    # value? checks directly without allocation.
    class HashValuesInclude < Base
      self.pattern_id = :hash_values_include
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        # Look for: .include?(arg) where receiver is .values
        return unless node.name == :include? && node.arguments&.arguments&.size == 1

        receiver = node.receiver
        return unless receiver.is_a?(Prism::CallNode)
        return unless receiver.name == :values

        add_finding(
          node,
          message: "Use `.value?(x)` instead of `.values.include?(x)` to avoid intermediate array",
          speedup: "Avoids creating intermediate array of values"
        )
      end
    end
  end
end
