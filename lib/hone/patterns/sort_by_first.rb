# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: array.sort_by { }.first -> array.min_by { }
    #
    # sort_by { block }.first sorts the entire array then takes the first element.
    # min_by { block } directly finds the minimum without creating intermediate array.
    class SortByFirst < Base
      self.pattern_id = :sort_by_first
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        # Look for: .first where receiver is .sort_by { block }
        return unless node.name == :first && node.arguments.nil?

        receiver = node.receiver
        return unless receiver.is_a?(Prism::CallNode) && receiver.name == :sort_by
        return unless block_attached?(receiver)

        add_finding(
          node,
          message: "Use `.min_by { }` instead of `.sort_by { }.first` to avoid sorting entire array",
          speedup: "Avoids sorting entire array"
        )
      end
    end
  end
end
