# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: array.select { }.map { } -> array.filter_map { }
    #
    # select.map creates an intermediate array from select, then maps over it.
    # filter_map combines both operations in a single pass, avoiding the
    # intermediate allocation.
    class SelectMap < Base
      self.pattern_id = :select_map
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        # Look for: .map { } where receiver is .select { }
        return unless node.name == :map && block_attached?(node)

        receiver = node.receiver
        return unless receiver.is_a?(Prism::CallNode)
        return unless receiver.name == :select && block_attached?(receiver)

        add_finding(
          node,
          message: "Use `.filter_map { }` instead of `.select { }.map { }` to avoid intermediate array",
          speedup: "~1.5x faster, avoids intermediate array"
        )
      end
    end
  end
end
