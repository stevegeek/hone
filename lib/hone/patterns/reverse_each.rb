# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: array.reverse.each { } -> array.reverse_each { }
    #
    # Calling .reverse.each creates an intermediate reversed array.
    # Using .reverse_each iterates in reverse order without allocation.
    class ReverseEach < Base
      self.pattern_id = :reverse_each
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        # Look for: .each { } where receiver is .reverse
        return unless node.name == :each && block_attached?(node)

        receiver = node.receiver
        return unless receiver.is_a?(Prism::CallNode) && receiver.name == :reverse

        add_finding(
          node,
          message: "Use `.reverse_each { }` instead of `.reverse.each { }` to avoid intermediate array",
          speedup: "~2x faster, avoids intermediate array allocation"
        )
      end
    end
  end
end
