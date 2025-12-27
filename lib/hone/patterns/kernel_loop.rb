# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: Kernel#loop { break if ... } -> while true ... end
    #
    # Kernel#loop has method call overhead vs the while construct.
    #
    # From sqids-ruby commit 8a74142
    class KernelLoop < Base
      self.pattern_id = :kernel_loop
      self.optimization_type = :cpu

      def visit_call_node(node)
        super
        # Look for: loop { ... } (implicit receiver, block present)
        return unless node.name == :loop && node.receiver.nil? && node.block.is_a?(Prism::BlockNode)

        add_finding(
          node,
          message: "Use `while true ... end` instead of `loop { }` in hot paths to avoid method call overhead",
          speedup: "Minor, but adds up in tight loops"
        )
      end
    end
  end
end
