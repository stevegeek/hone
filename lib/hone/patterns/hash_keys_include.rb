# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: hash.keys.include?(key) -> hash.key?(key)
    #
    # keys.include? creates an array of all keys then searches it (O(n)).
    # key? does a direct hash lookup (O(1)).
    class HashKeysInclude < Base
      self.pattern_id = :hash_keys_include
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        # Look for: .include?(x) where receiver is .keys
        return unless node.name == :include? && node.arguments&.arguments&.size == 1

        receiver = node.receiver
        return unless receiver.is_a?(Prism::CallNode) && receiver.name == :keys

        add_finding(
          node,
          message: "Use `.key?(k)` instead of `.keys.include?(k)` for O(1) lookup without array allocation",
          speedup: "O(n) to O(1), avoids allocating array of all keys"
        )
      end
    end
  end
end
