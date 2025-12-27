# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: array.sort_by { }.last -> array.max_by { }
    #
    # sort_by { block }.last sorts the entire array then takes the last element.
    # max_by { block } directly finds the maximum without creating intermediate array.
    class SortByLast < Base
      self.pattern_id = :sort_by_last
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        # Look for: .last where receiver is .sort_by { block }
        return unless node.name == :last && node.arguments.nil?

        receiver = node.receiver
        return unless receiver.is_a?(Prism::CallNode) && receiver.name == :sort_by
        return unless block_attached?(receiver)

        add_finding(
          node,
          message: "Use `.max_by { }` instead of `.sort_by { }.last` to avoid sorting entire array",
          speedup: "Avoids sorting entire array"
        )
      end
    end
  end
end
