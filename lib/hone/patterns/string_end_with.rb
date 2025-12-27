# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: str[-1] == 'x' or str.match?(/x$/) -> str.end_with?('x')
    #
    # Indexing at position -1 for comparison or using regex with $ anchor
    # is less clear and potentially slower than using end_with?.
    #
    # @example Bad
    #   str[-1] == 'x'
    #   str.match?(/foo$/)
    #
    # @example Good
    #   str.end_with?('x')
    #   str.end_with?('foo')
    class StringEndWith < Base
      self.pattern_id = :string_end_with
      self.optimization_type = :cpu

      def visit_call_node(node)
        super

        if index_negative_one_comparison?(node)
          add_finding(
            node,
            message: "Use `end_with?` instead of `str[-1] == ...` for cleaner code",
            speedup: "Cleaner and avoids substring/regex overhead"
          )
        elsif regex_end_anchor?(node)
          add_finding(
            node,
            message: "Use `end_with?` instead of `match?(/...$/)` to avoid regex overhead",
            speedup: "Cleaner and avoids substring/regex overhead"
          )
        end
      end

      private

      # Detects: str[-1] == 'x' or 'x' == str[-1]
      def index_negative_one_comparison?(node)
        return false unless node.name == :==
        return false unless node.arguments&.arguments&.size == 1

        receiver = node.receiver
        arg = node.arguments.arguments[0]

        # Check receiver[-1] == arg or arg == receiver[-1]
        index_at_negative_one?(receiver) || index_at_negative_one?(arg)
      end

      # Detects: str.match?(/...$/)
      def regex_end_anchor?(node)
        return false unless node.name == :match?
        return false unless node.arguments&.arguments&.size == 1

        arg = node.arguments.arguments[0]
        return false unless arg.is_a?(Prism::RegularExpressionNode)

        # Check if regex ends with $ anchor (and $ is not escaped)
        content = arg.content
        content.end_with?("$") && !content.end_with?("\\$")
      end

      # Check if node is a [] call with index -1
      def index_at_negative_one?(node)
        return false unless node.is_a?(Prism::CallNode)
        return false unless node.name == :[]
        return false unless node.arguments&.arguments&.size == 1

        index_arg = node.arguments.arguments[0]
        integer_negative_one?(index_arg)
      end

      def integer_negative_one?(node)
        node.is_a?(Prism::IntegerNode) && node.value == -1
      end
    end
  end
end
