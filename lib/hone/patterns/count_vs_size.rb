# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: array.count (no block) -> array.size or array.length
    #
    # When `count` is called without a block on an Array, it's slower than
    # `size`/`length` because count is designed for enumerables and does more work.
    # `.size` and `.length` are O(1) operations for Arrays as they simply return
    # the cached length, while `.count` may iterate.
    class CountVsSize < Base
      self.pattern_id = :count_vs_size
      self.optimization_type = :cpu

      def visit_call_node(node)
        super
        # Look for: receiver.count with no arguments and no block
        return unless node.name == :count && no_arguments?(node) && node.block.nil?

        add_finding(
          node,
          message: "Use `.size` or `.length` instead of `.count` when counting all elements",
          speedup: "Minor, but `.size` is O(1) for Arrays vs `.count` which may iterate"
        )
      end

      private

      # Check if the node has no arguments
      def no_arguments?(node)
        node.arguments.nil? || node.arguments.arguments.empty?
      end
    end
  end
end
