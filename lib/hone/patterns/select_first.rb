# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: array.select { }.first -> array.detect { } / array.find { }
    #
    # select.first iterates the entire array building a new array, then takes first.
    # detect/find stops iteration as soon as a match is found.
    class SelectFirst < Base
      self.pattern_id = :select_first
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        # Look for: .first where receiver is .select with a block
        return unless node.name == :first && node.arguments.nil?

        receiver = node.receiver
        return unless receiver.is_a?(Prism::CallNode)
        return unless receiver.name == :select && block_attached?(receiver)

        add_finding(
          node,
          message: "Use `.detect { }` or `.find { }` instead of `.select { }.first` to stop at first match",
          speedup: "Avoids iterating entire array and intermediate array allocation"
        )
      end
    end
  end
end
