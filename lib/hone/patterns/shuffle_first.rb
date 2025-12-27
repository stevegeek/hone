# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: array.shuffle.first -> array.sample
    #
    # shuffle.first shuffles the entire array then takes the first element.
    # sample directly selects a random element without creating intermediate array.
    class ShuffleFirst < Base
      self.pattern_id = :shuffle_first
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        # Look for: .first where receiver is .shuffle
        return unless node.name == :first && node.arguments.nil?

        receiver = node.receiver
        return unless receiver.is_a?(Prism::CallNode) && receiver.name == :shuffle

        add_finding(
          node,
          message: "Use `.sample` instead of `.shuffle.first` to avoid shuffling entire array",
          speedup: "Avoids O(n) shuffle and intermediate array allocation"
        )
      end
    end
  end
end
