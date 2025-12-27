# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: array.reverse.first -> array.last
    #         array.reverse.first(n) -> array.last(n).reverse
    #
    # reverse.first reverses the entire array then takes the first element(s).
    # Using last directly accesses the end of the array without creating an
    # intermediate reversed array.
    class ReverseFirst < Base
      self.pattern_id = :reverse_first
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        # Look for: .first or .first(n) where receiver is .reverse
        return unless node.name == :first

        receiver = node.receiver
        return unless receiver.is_a?(Prism::CallNode) && receiver.name == :reverse

        if node.arguments.nil?
          add_finding(
            node,
            message: "Use `.last` instead of `.reverse.first` to avoid reversing entire array",
            speedup: "Avoids reversing entire array"
          )
        else
          add_finding(
            node,
            message: "Use `.last(n).reverse` instead of `.reverse.first(n)` to avoid reversing entire array",
            speedup: "Avoids reversing entire array"
          )
        end
      end
    end
  end
end
