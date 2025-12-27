# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: hash.keys.each { } -> hash.each_key { }
    #
    # keys.each creates an intermediate array of keys then iterates.
    # each_key iterates keys directly without allocation.
    #
    # Also detects hash.values.each { } -> hash.each_value { }
    class HashEachKey < Base
      self.pattern_id = :hash_each_key
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        # Look for: .each { } where receiver is .keys or .values
        return unless node.name == :each && block_attached?(node)

        receiver = node.receiver
        return unless receiver.is_a?(Prism::CallNode)

        case receiver.name
        when :keys
          add_finding(
            node,
            message: "Use `.each_key { }` instead of `.keys.each { }` to avoid intermediate array",
            speedup: "Iterates keys directly without allocating array"
          )
        when :values
          add_finding(
            node,
            message: "Use `.each_value { }` instead of `.values.each { }` to avoid intermediate array",
            speedup: "Iterates values directly without allocating array"
          )
        end
      end
    end
  end
end
