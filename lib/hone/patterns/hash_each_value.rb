# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: hash.values.each { } -> hash.each_value { }
    #
    # values.each creates an intermediate array of values then iterates.
    # each_value iterates values directly without allocation.
    class HashEachValue < Base
      self.pattern_id = :hash_each_value
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        # Look for: .each { } where receiver is .values
        return unless node.name == :each && block_attached?(node)

        receiver = node.receiver
        return unless receiver.is_a?(Prism::CallNode)
        return unless receiver.name == :values

        add_finding(
          node,
          message: "Use `.each_value { }` instead of `.values.each { }` to avoid intermediate array",
          speedup: "Avoids creating intermediate array of values"
        )
      end
    end
  end
end
