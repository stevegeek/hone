# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: array.inject(0, :+) -> array.sum
    #
    # sum is optimized for numeric summation with native implementation.
    # Also handles empty arrays correctly (returns 0).
    class InjectSum < Base
      self.pattern_id = :inject_sum
      self.optimization_type = :cpu

      def visit_call_node(node)
        super

        return unless %i[inject reduce].include?(node.name)
        return unless sum_pattern?(node)

        add_finding(
          node,
          message: "Use `.sum` instead of `.#{node.name}(:+)` for optimized numeric summation",
          speedup: "Native C implementation, cleaner code"
        )
      end

      private

      def sum_pattern?(node)
        args = node.arguments&.arguments
        return false unless args

        # Pattern 1: inject(:+) or reduce(:+)
        if args.size == 1
          arg = args.first
          return true if arg.is_a?(Prism::SymbolNode) && arg.value == "+"
        end

        # Pattern 2: inject(0, :+) or reduce(0, :+)
        if args.size == 2
          second_arg = args[1]
          return true if second_arg.is_a?(Prism::SymbolNode) && second_arg.value == "+"
        end

        false
      end
    end
  end
end
