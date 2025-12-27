# frozen_string_literal: true

module Hone
  module Patterns
    # Detects `str.chars[i]` which should be `str[i]`
    #
    # str.chars[n] creates an array of single-character strings, then indexes it.
    # Direct string indexing is much faster.
    #
    # @example Bad
    #   str.chars[0]
    #   str.chars.first
    #   str.chars.last
    #
    # @example Good
    #   str[0]
    #   str[0]
    #   str[-1]
    #
    class RedundantStringChars < Base
      self.pattern_id = :redundant_string_chars
      self.optimization_type = :allocation

      def visit_call_node(node)
        if chained_chars_index?(node)
          replacement = suggest_replacement(node)
          add_finding(
            node,
            message: "Use `#{replacement}` instead of `chars[...]` to avoid array allocation",
            speedup: "Significant - avoids creating array of all characters"
          )
        elsif chained_chars_first_last?(node)
          replacement = suggest_first_last_replacement(node)
          add_finding(
            node,
            message: "Use `#{replacement}` instead of `chars.#{node.name}` to avoid array allocation",
            speedup: "Significant - avoids creating array of all characters"
          )
        end

        super
      end

      private

      def chained_chars_index?(node)
        return false unless node.name == :[]

        receiver = node.receiver
        return false unless receiver.is_a?(Prism::CallNode)
        return false unless receiver.name == :chars

        true
      end

      def chained_chars_first_last?(node)
        return false unless %i[first last].include?(node.name)

        receiver = node.receiver
        return false unless receiver.is_a?(Prism::CallNode)
        return false unless receiver.name == :chars

        true
      end

      def suggest_replacement(node)
        receiver = node.receiver.receiver
        receiver_src = receiver ? receiver.slice : "str"
        args = node.arguments&.arguments&.first
        index = args ? args.slice : "i"
        "#{receiver_src}[#{index}]"
      end

      def suggest_first_last_replacement(node)
        receiver = node.receiver.receiver
        receiver_src = receiver ? receiver.slice : "str"
        index = (node.name == :first) ? "0" : "-1"
        "#{receiver_src}[#{index}]"
      end
    end
  end
end
