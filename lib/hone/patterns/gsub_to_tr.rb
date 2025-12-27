# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: str.gsub('a', 'b') -> str.tr('a', 'b')
    #
    # For replacing single characters, tr is optimized and faster than gsub.
    # gsub has regex overhead even for simple string patterns.
    class GsubToTr < Base
      self.pattern_id = :gsub_to_tr
      self.optimization_type = :cpu

      def visit_call_node(node)
        super

        return unless node.name == :gsub

        args = node.arguments&.arguments
        return unless args&.size == 2

        first_arg = args[0]
        second_arg = args[1]

        # Check if both arguments are single-character strings
        return unless single_char_string?(first_arg) && single_char_string?(second_arg)

        add_finding(
          node,
          message: "Use `.tr('#{string_value(first_arg)}', '#{string_value(second_arg)}')` instead of `.gsub` for single character replacement",
          speedup: "tr is optimized for character translation, avoids regex overhead"
        )
      end

      private

      def single_char_string?(node)
        return false unless node.is_a?(Prism::StringNode)

        content = node.content
        content.is_a?(String) && content.length == 1
      end

      def string_value(node)
        node.content
      end
    end
  end
end
