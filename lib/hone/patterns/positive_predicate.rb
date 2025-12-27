# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: (expr).positive? -> (expr) > 0
    #
    # In hot paths, the method call overhead of .positive? can add up.
    # Direct comparison is faster.
    #
    # From sqids-ruby commit 8a74142
    class PositivePredicate < Base
      self.pattern_id = :positive_predicate
      self.optimization_type = :cpu

      def visit_call_node(node)
        super
        return unless node.name == :positive? && node.arguments.nil?

        add_finding(
          node,
          message: "Use `> 0` instead of `.positive?` in hot paths to avoid method call overhead",
          speedup: "Minor, but adds up in tight loops"
        )
      end
    end
  end
end
