# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: array.map { }.uniq -> consider array.uniq { }
    #
    # map { }.uniq creates an intermediate array from map, then deduplicates.
    # If deduplicating on the transformed value, uniq { } avoids the intermediate.
    class UniqBy < Base
      self.pattern_id = :uniq_by
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        # Look for: .uniq where receiver is .map with a block
        return unless node.name == :uniq
        return unless node.arguments.nil? && !block_attached?(node)

        receiver = node.receiver
        return unless receiver.is_a?(Prism::CallNode)
        return unless receiver.name == :map && block_attached?(receiver)

        add_finding(
          node,
          message: "Consider `.uniq { }` instead of `.map { }.uniq` if deduping on transform",
          speedup: "May avoid intermediate array if deduping on transform"
        )
      end
    end
  end
end
