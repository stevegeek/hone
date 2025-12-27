# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: sorted_array.find { |x| x >= target } -> sorted_array.bsearch { |x| x >= target }
    #
    # When searching sorted data for the first element matching a comparison,
    # bsearch uses binary search (O(log n)) vs find's linear search (O(n)).
    #
    # This pattern is conservative and only reports when it detects:
    # - find with a block containing >= or > comparison
    # - The receiver name contains hints like "sorted" or common sorted collection names
    class BsearchVsFind < Base
      self.pattern_id = :bsearch_vs_find
      self.optimization_type = :cpu

      # Names that suggest the array is sorted
      SORTED_HINTS = %w[sorted ordered ranked].freeze

      def visit_call_node(node)
        super

        return unless node.name == :find
        return unless block_attached?(node)

        block = node.block
        return unless block.is_a?(Prism::BlockNode)
        return unless comparison_block?(block)
        return unless likely_sorted_receiver?(node.receiver)

        add_finding(
          node,
          message: "Consider `.bsearch { }` instead of `.find { }` for O(log n) search on sorted data",
          speedup: "O(log n) vs O(n) for sorted data"
        )
      end

      private

      # Check if block body contains a >= or > comparison
      def comparison_block?(block)
        body = block.body
        return false unless body.is_a?(Prism::StatementsNode)
        return false unless body.body.size == 1

        statement = body.body.first
        comparison_expression?(statement)
      end

      def comparison_expression?(node)
        return false unless node.is_a?(Prism::CallNode)

        %i[>= > <= <].include?(node.name)
      end

      # Conservative check: only flag if receiver name hints at sorted data
      def likely_sorted_receiver?(receiver)
        return false unless receiver

        name = extract_receiver_name(receiver)
        return false unless name

        name_str = name.to_s.downcase
        SORTED_HINTS.any? { |hint| name_str.include?(hint) }
      end

      def extract_receiver_name(node)
        case node
        when Prism::LocalVariableReadNode
          node.name
        when Prism::InstanceVariableReadNode
          node.name.to_s.delete_prefix("@")
        when Prism::CallNode
          # For method calls like foo.bar, use the method name
          node.name
        end
      end
    end
  end
end
