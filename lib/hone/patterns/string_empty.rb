# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: str.length == 0 or str.size == 0 -> str.empty?
    #
    # Comparing length/size to 0 is less idiomatic than using empty?.
    # empty? is the Ruby way to check for emptiness.
    #
    # @example Bad
    #   str.length == 0
    #   str.size == 0
    #   0 == str.length
    #   0 == str.size
    #
    # @example Good
    #   str.empty?
    class StringEmpty < Base
      self.pattern_id = :string_empty
      self.optimization_type = :cpu

      def visit_call_node(node)
        super

        return unless length_or_size_equals_zero?(node)

        add_finding(
          node,
          message: "Use `empty?` instead of comparing `length`/`size` to 0",
          speedup: "Minor, but more idiomatic"
        )
      end

      private

      # Detects: str.length == 0 or str.size == 0 or 0 == str.length or 0 == str.size
      def length_or_size_equals_zero?(node)
        return false unless node.name == :==
        return false unless node.arguments&.arguments&.size == 1

        receiver = node.receiver
        arg = node.arguments.arguments[0]

        # Check: receiver.length/size == 0 or 0 == receiver.length/size
        (length_or_size_call?(receiver) && integer_zero?(arg)) ||
          (integer_zero?(receiver) && length_or_size_call?(arg))
      end

      def length_or_size_call?(node)
        return false unless node.is_a?(Prism::CallNode)

        %i[length size].include?(node.name) && no_arguments?(node)
      end

      def no_arguments?(node)
        node.arguments.nil? || node.arguments.arguments.empty?
      end

      def integer_zero?(node)
        node.is_a?(Prism::IntegerNode) && node.value == 0
      end
    end
  end
end
