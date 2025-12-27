# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: array.map { ... }.select { ... } -> array.filter_map { ... }
    #
    # Chaining .map and .select creates an intermediate array.
    # Using .filter_map combines both operations in one pass.
    #
    # From sqids-ruby commit aa4e253
    class MapSelectChain < Base
      self.pattern_id = :map_select_chain
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        # Look for: .select { } where receiver is .map (with block or symbol arg)
        return unless node.name == :select && block_attached?(node)

        receiver = node.receiver
        return unless receiver.is_a?(Prism::CallNode) && receiver.name == :map && block_attached?(receiver)

        add_finding(
          node,
          message: "Use `.filter_map { }` instead of `.map { }.select { }` to avoid intermediate array",
          speedup: "Fewer allocations"
        )
      end
    end
  end
end
