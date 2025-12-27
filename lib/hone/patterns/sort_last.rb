# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: array.sort.last -> array.max
    #
    # sort.last sorts the entire array then takes the last element.
    # max directly finds the maximum without creating intermediate array.
    class SortLast < Base
      self.pattern_id = :sort_last
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        # Look for: .last or .last(n) where receiver is .sort
        return unless node.name == :last

        receiver = node.receiver
        return unless receiver.is_a?(Prism::CallNode) && receiver.name == :sort

        add_finding(
          node,
          message: "Use `.max` instead of `.sort.last` to avoid sorting entire array",
          speedup: "Avoids sorting entire array"
        )
      end
    end
  end
end
