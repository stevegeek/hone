# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: array.include?(x) -> consider Set for repeated lookups
    #
    # Array#include? is O(n) for each lookup.
    # If performing repeated lookups, converting to Set gives O(1) lookups.
    class ArrayIncludeSet < Base
      self.pattern_id = :array_include_set
      self.optimization_type = :cpu

      def visit_call_node(node)
        super

        # Look for: .include?(x) with one argument
        return unless node.name == :include?
        return unless node.arguments&.arguments&.size == 1

        # Skip if receiver is a known hash method chain (handled by hash_keys_include)
        receiver = node.receiver
        if receiver.is_a?(Prism::CallNode)
          return if receiver.name == :keys || receiver.name == :values
        end

        add_finding(
          node,
          message: "Consider using Set instead of Array#include? for repeated lookups",
          speedup: "O(1) vs O(n) for repeated lookups"
        )
      end
    end
  end
end
