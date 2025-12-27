# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: array.map { }.compact -> array.filter_map { }
    #
    # map.compact creates an intermediate array from map that may contain nils,
    # then compacts it. filter_map combines both operations avoiding the
    # intermediate allocation.
    class MapCompact < Base
      self.pattern_id = :map_compact
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        # Look for: .compact where receiver is .map with a block
        return unless node.name == :compact

        receiver = node.receiver
        return unless receiver.is_a?(Prism::CallNode)
        return unless receiver.name == :map && block_attached?(receiver)

        add_finding(
          node,
          message: "Use `.filter_map { }` instead of `.map { }.compact` to avoid intermediate array with nils",
          speedup: "Avoids intermediate array with nils"
        )
      end
    end
  end
end
