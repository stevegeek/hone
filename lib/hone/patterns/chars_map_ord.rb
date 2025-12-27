# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: str.chars.map(&:ord) -> str.codepoints
    #
    # The .chars.map(&:ord) chain creates an intermediate array of single-char
    # strings, then maps each to its ordinal. Using .codepoints directly is
    # faster and allocates less memory.
    #
    # From sqids-ruby commit 9413b68
    class CharsMapOrd < Base
      self.pattern_id = :chars_map_ord
      self.optimization_type = :allocation

      def visit_call_node(node)
        super
        # Look for: .map(&:ord) where receiver is .chars
        return unless node.name == :map && block_arg_is_symbol?(node, :ord)

        receiver = node.receiver
        return unless receiver.is_a?(Prism::CallNode) && receiver.name == :chars

        add_finding(
          node,
          message: "Use `.codepoints` instead of `.chars.map(&:ord)` to avoid intermediate array allocation",
          speedup: "Fewer allocations"
        )
      end

      private

      def block_arg_is_symbol?(call_node, sym_name)
        block_arg = call_node.block
        return false unless block_arg.is_a?(Prism::BlockArgumentNode)

        expr = block_arg.expression
        expr.is_a?(Prism::SymbolNode) && expr.value == sym_name.to_s
      end
    end
  end
end
