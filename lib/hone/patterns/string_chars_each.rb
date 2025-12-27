# frozen_string_literal: true

module Hone
  module Patterns
    # Detects `str.chars.each { }` which should be `str.each_char { }`
    #
    # chars.each creates an intermediate array of single-character strings.
    # each_char iterates directly without allocation.
    #
    # @example Bad
    #   str.chars.each { |c| puts c }
    #
    # @example Good
    #   str.each_char { |c| puts c }
    #
    class StringCharsEach < Base
      self.pattern_id = :string_chars_each
      self.optimization_type = :allocation

      def visit_call_node(node)
        if chained_chars_each?(node)
          replacement = suggest_replacement(node)
          add_finding(
            node,
            message: "Use `#{replacement}` instead of `chars.each` to avoid intermediate array allocation",
            speedup: "No intermediate array allocation"
          )
        end

        super
      end

      private

      def chained_chars_each?(node)
        return false unless node.name == :each && has_block?(node)

        receiver = node.receiver
        return false unless receiver.is_a?(Prism::CallNode)
        return false unless receiver.name == :chars

        true
      end

      def suggest_replacement(node)
        receiver = node.receiver.receiver
        receiver_src = receiver ? receiver.slice : "str"
        "#{receiver_src}.each_char { ... }"
      end

      def has_block?(node)
        node.block.is_a?(Prism::BlockNode) || node.block.is_a?(Prism::BlockArgumentNode)
      end
    end
  end
end
