# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: [n / d, n % d] -> n.divmod(d)
    #
    # When you need both quotient and remainder, divmod computes them
    # in a single operation instead of performing division twice.
    class Divmod < Base
      self.pattern_id = :divmod
      self.optimization_type = :cpu

      def visit_array_node(node)
        super

        elements = node.elements
        return unless elements.size == 2

        first = elements[0]
        second = elements[1]

        return unless division_operation?(first) && modulo_operation?(second)
        return unless same_operands?(first, second)

        add_finding(
          node,
          message: "Use `.divmod` instead of `[n / d, n % d]` for single operation",
          speedup: "Single operation instead of two"
        )
      end

      private

      def division_operation?(node)
        return false unless node.is_a?(Prism::CallNode)

        node.name == :/
      end

      def modulo_operation?(node)
        return false unless node.is_a?(Prism::CallNode)

        node.name == :%
      end

      def same_operands?(div_node, mod_node)
        # Both should have receiver (dividend) and one argument (divisor)
        return false unless div_node.receiver && mod_node.receiver
        return false unless div_node.arguments&.arguments&.size == 1
        return false unless mod_node.arguments&.arguments&.size == 1

        # Compare receivers (dividend)
        return false unless nodes_equivalent?(div_node.receiver, mod_node.receiver)

        # Compare arguments (divisor)
        div_arg = div_node.arguments.arguments.first
        mod_arg = mod_node.arguments.arguments.first
        nodes_equivalent?(div_arg, mod_arg)
      end

      # Simple equivalence check for common node types
      def nodes_equivalent?(node1, node2)
        return false unless node1.instance_of?(node2.class)

        case node1
        when Prism::LocalVariableReadNode
          node1.name == node2.name
        when Prism::InstanceVariableReadNode
          node1.name == node2.name
        when Prism::ClassVariableReadNode
          node1.name == node2.name
        when Prism::GlobalVariableReadNode
          node1.name == node2.name
        when Prism::IntegerNode
          node1.value == node2.value
        when Prism::CallNode
          # For method calls, check name and receiver
          return false unless node1.name == node2.name

          if node1.receiver && node2.receiver
            nodes_equivalent?(node1.receiver, node2.receiver)
          else
            node1.receiver.nil? && node2.receiver.nil?
          end
        else
          # For other node types, compare the source directly
          node1.location.slice == node2.location.slice
        end
      end
    end
  end
end
