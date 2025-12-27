# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: array.map { }.flatten -> array.flat_map { }
    #
    # map.flatten creates an intermediate array from map, then flattens it.
    # flat_map combines both operations avoiding the intermediate allocation.
    class MapFlatten < Base
      self.pattern_id = :map_flatten
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        # Look for: .flatten where receiver is .map with a block
        return unless node.name == :flatten

        receiver = node.receiver
        return unless receiver.is_a?(Prism::CallNode)
        return unless receiver.name == :map && block_attached?(receiver)

        add_finding(
          node,
          message: "Use `.flat_map { }` instead of `.map { }.flatten` to avoid intermediate array",
          speedup: "Single pass, no intermediate allocation"
        )
      end
    end
  end
end
