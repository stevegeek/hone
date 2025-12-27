# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: str.downcase == other.downcase -> str.casecmp?(other)
    #
    # casecmp? performs case-insensitive comparison without creating
    # intermediate lowercase/uppercase strings, reducing allocations.
    class StringCasecmp < Base
      self.pattern_id = :string_casecmp
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        return unless node.name == :==

        # The receiver should be a call to downcase or upcase
        receiver = node.receiver
        return unless case_conversion_call?(receiver)

        # The argument should also be a call to downcase or upcase
        args = node.arguments&.arguments
        return unless args&.size == 1

        arg = args[0]
        return unless case_conversion_call?(arg)

        # Both should use the same case conversion method
        receiver_method = receiver.name
        arg_method = arg.name
        return unless receiver_method == arg_method

        method_name = (receiver_method == :downcase) ? "downcase" : "upcase"

        add_finding(
          node,
          message: "Use `.casecmp?(other)` instead of `.#{method_name} == other.#{method_name}`",
          speedup: "Avoids creating intermediate lowercase strings"
        )
      end

      private

      def case_conversion_call?(node)
        return false unless node.is_a?(Prism::CallNode)

        (node.name == :downcase || node.name == :upcase) &&
          node.arguments.nil? &&
          !block_attached?(node)
      end
    end
  end
end
