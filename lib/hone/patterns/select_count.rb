# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: array.select { }.count -> array.count { }
    #
    # select { }.count creates a temporary array of matches then counts it.
    # count { } counts matches directly without intermediate allocation.
    class SelectCount < Base
      self.pattern_id = :select_count
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        # Look for: .count/.size/.length (no args) where receiver is .select with block
        return unless %i[count size length].include?(node.name)
        return unless node.arguments.nil?

        receiver = node.receiver
        return unless receiver.is_a?(Prism::CallNode)
        return unless receiver.name == :select && block_attached?(receiver)

        add_finding(
          node,
          message: "Use `.count { }` instead of `.select { }.#{node.name}` to avoid intermediate array",
          speedup: "Counts directly without allocating intermediate array"
        )
      end
    end
  end
end
