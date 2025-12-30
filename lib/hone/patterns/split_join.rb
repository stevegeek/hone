# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: str.split(x).join(y) -> use gsub or tr
    #
    # When just replacing delimiters, split/join allocates unnecessarily:
    # 1. An array from split
    # 2. Final joined string
    #
    # Use gsub (for patterns) or tr (for single chars) instead.
    #
    # Example:
    #   # Before - allocates array
    #   path.split('/').join('\\')
    #
    #   # After - no intermediate array
    #   path.tr('/', '\\')      # single char
    #   path.gsub('/', '\\')    # or gsub
    #
    class SplitJoin < Base
      self.pattern_id = :split_join
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        # Look for .join(...) call
        return unless node.name == :join

        # Check if receiver is .split(...) directly (no map in between)
        split_node = node.receiver
        return unless split_node.is_a?(Prism::CallNode)
        return unless split_node.name == :split

        # Make sure it's not split.map.join (handled by other pattern)
        # split.join means the receiver of join is directly the split call

        # Check if both split and join use single character strings
        split_arg = split_node.arguments&.arguments&.first
        join_arg = node.arguments&.arguments&.first

        single_char_split = single_char_string?(split_arg)
        single_char_join = single_char_string?(join_arg)

        if single_char_split && single_char_join
          add_finding(
            node,
            message: "Use `tr('#{extract_char(split_arg)}', '#{extract_char(join_arg)}')` instead of `split().join()` to avoid array allocation",
            speedup: "Avoids array allocation, in-place transformation"
          )
        else
          add_finding(
            node,
            message: "Consider using `gsub` instead of `split().join()` to avoid array allocation",
            speedup: "Avoids array allocation"
          )
        end
      end

      private

      def single_char_string?(node)
        return false unless node.is_a?(Prism::StringNode)
        node.unescaped.length == 1
      end

      def extract_char(node)
        return "" unless node.is_a?(Prism::StringNode)
        node.unescaped
      end
    end
  end
end
