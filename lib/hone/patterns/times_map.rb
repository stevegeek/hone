# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: n.times.map { } -> Array.new(n) { }
    #
    # times.map creates an Enumerator then maps over it.
    # Array.new(n) { } directly creates the array with the block values,
    # avoiding the Enumerator overhead.
    #
    # Examples:
    #   # Bad: creates Enumerator then maps
    #   5.times.map { |i| i * 2 }
    #   # Good: direct array creation
    #   Array.new(5) { |i| i * 2 }
    class TimesMap < Base
      self.pattern_id = :times_map
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        # Look for: .map { } where receiver is .times
        return unless node.name == :map && block_attached?(node)

        receiver = node.receiver
        return unless receiver.is_a?(Prism::CallNode)
        return unless receiver.name == :times

        add_finding(
          node,
          message: "Use `Array.new(n) { }` instead of `n.times.map { }` to avoid Enumerator overhead",
          speedup: "~2x faster, avoids Enumerator overhead"
        )
      end
    end
  end
end
