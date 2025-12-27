# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: str[0] == 'x' or str.match?(/^x/) -> str.start_with?('x')
    #
    # Indexing at position 0 for comparison or using regex with ^ anchor
    # is less clear and potentially slower than using start_with?.
    #
    # @example Bad
    #   str[0] == 'x'
    #   str.match?(/^foo/)
    #
    # @example Good
    #   str.start_with?('x')
    #   str.start_with?('foo')
    class StringStartWith < Base
      self.pattern_id = :string_start_with
      self.optimization_type = :cpu

      def visit_call_node(node)
        super

        if index_zero_comparison?(node)
          add_finding(
            node,
            message: "Use `start_with?` instead of `str[0] == ...` for cleaner code",
            speedup: "Cleaner and avoids substring/regex overhead"
          )
        elsif regex_start_anchor?(node)
          add_finding(
            node,
            message: "Use `start_with?` instead of `match?(/^.../)` to avoid regex overhead",
            speedup: "Cleaner and avoids substring/regex overhead"
          )
        end
      end

      private

      # Detects: str[0] == 'x' or 'x' == str[0]
      def index_zero_comparison?(node)
        return false unless node.name == :==
        return false unless node.arguments&.arguments&.size == 1

        receiver = node.receiver
        arg = node.arguments.arguments[0]

        # Check receiver[0] == arg or arg == receiver[0]
        index_at_zero?(receiver) || index_at_zero?(arg)
      end

      # Detects: str.match?(/^.../)
      def regex_start_anchor?(node)
        return false unless node.name == :match?
        return false unless node.arguments&.arguments&.size == 1

        arg = node.arguments.arguments[0]
        return false unless arg.is_a?(Prism::RegularExpressionNode)

        # Check if regex starts with ^ anchor
        arg.content.start_with?("^")
      end

      # Check if node is a [] call with index 0
      def index_at_zero?(node)
        return false unless node.is_a?(Prism::CallNode)
        return false unless node.name == :[]
        return false unless node.arguments&.arguments&.size == 1

        index_arg = node.arguments.arguments[0]
        integer_zero?(index_arg)
      end

      def integer_zero?(node)
        node.is_a?(Prism::IntegerNode) && node.value == 0
      end
    end
  end
end
