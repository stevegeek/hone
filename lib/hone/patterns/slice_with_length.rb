# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: str[n, str.length] -> str[n..]
    #
    # Endless range syntax avoids the length calculation.
    #
    # From sqids-ruby commit 9413b68
    class SliceWithLength < Base
      self.pattern_id = :slice_with_length
      self.optimization_type = :cpu

      def visit_call_node(node)
        super

        # Look for: receiver[offset, receiver.length] pattern
        return unless node.name == :[] && node.arguments

        args = node.arguments.arguments
        return unless args&.length == 2

        first_arg = args[0]
        second_arg = args[1]

        # Check if second arg is receiver.length or receiver.size
        return unless second_arg.is_a?(Prism::CallNode)
        return unless %i[length size].include?(second_arg.name)
        return unless nodes_match?(node.receiver, second_arg.receiver)

        add_finding(
          node,
          message: "Use endless range `[#{first_arg.location.slice}..]` instead of `[#{first_arg.location.slice}, #{second_arg.location.slice}]`",
          speedup: "Minor, avoids length calculation"
        )
      end

      private

      # Simple check if two nodes represent the same variable/expression
      def nodes_match?(node1, node2)
        return false unless node1.instance_of?(node2.class)

        node1.location.slice == node2.location.slice
      end
    end
  end
end
