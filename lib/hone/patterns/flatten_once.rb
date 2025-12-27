# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: array.flatten -> consider array.flatten(1)
    #
    # flatten without an argument flattens all levels recursively.
    # If you only need one level, flatten(1) is faster.
    class FlattenOnce < Base
      self.pattern_id = :flatten_once
      self.optimization_type = :cpu

      def visit_call_node(node)
        super

        # Look for: .flatten without arguments
        return unless node.name == :flatten
        return unless node.arguments.nil?

        add_finding(
          node,
          message: "Consider `.flatten(1)` if only one level of flattening is needed",
          speedup: "Faster when you only need one level"
        )
      end
    end
  end
end
