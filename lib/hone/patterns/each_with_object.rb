# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: inject({}) { |acc, x| ... ; acc } -> each_with_object({}) { |x, acc| }
    #
    # inject/reduce with a hash or array accumulator requires returning the
    # accumulator at the end of each block iteration. each_with_object
    # automatically passes the same object, making the code cleaner and
    # avoiding the need to return the accumulator.
    #
    # Examples:
    #   # Bad: must return acc at end of block
    #   items.inject({}) { |acc, x| acc[x.id] = x; acc }
    #   # Good: acc is automatically passed
    #   items.each_with_object({}) { |x, acc| acc[x.id] = x }
    class EachWithObject < Base
      self.pattern_id = :each_with_object
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        return unless %i[inject reduce].include?(node.name)
        return unless block_attached?(node)
        return unless empty_collection_initial_value?(node)

        add_finding(
          node,
          message: "Consider using `.each_with_object(#{initial_value_literal(node)})` instead of `.#{node.name}(#{initial_value_literal(node)})` for cleaner accumulator pattern",
          speedup: "Cleaner, avoids returning accumulator each iteration"
        )
      end

      private

      def empty_collection_initial_value?(node)
        args = node.arguments&.arguments
        return false unless args&.size == 1

        arg = args.first
        empty_hash?(arg) || empty_array?(arg)
      end

      def empty_hash?(arg)
        arg.is_a?(Prism::HashNode) && arg.elements.empty?
      end

      def empty_array?(arg)
        arg.is_a?(Prism::ArrayNode) && arg.elements.empty?
      end

      def initial_value_literal(node)
        arg = node.arguments.arguments.first
        if arg.is_a?(Prism::HashNode)
          "{}"
        else
          "[]"
        end
      end
    end
  end
end
