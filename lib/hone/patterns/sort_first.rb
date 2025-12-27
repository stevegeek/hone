# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: array.sort.first -> array.min, array.sort.last -> array.max
    #
    # sort.first/last sorts the entire array O(n log n) then takes one element.
    # min/max finds the element in a single O(n) pass without sorting.
    class SortFirst < Base
      self.pattern_id = :sort_first
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        return unless %i[first last].include?(node.name) && node.arguments.nil?

        receiver = node.receiver
        return unless receiver.is_a?(Prism::CallNode)

        case [receiver.name, node.name]
        when [:sort, :first]
          add_finding(
            node,
            message: "Use `.min` instead of `.sort.first` to find minimum in O(n) without sorting",
            speedup: "O(n log n) sort to O(n) single pass, no intermediate array"
          )
        when [:sort, :last]
          add_finding(
            node,
            message: "Use `.max` instead of `.sort.last` to find maximum in O(n) without sorting",
            speedup: "O(n log n) sort to O(n) single pass, no intermediate array"
          )
        when [:sort_by, :first]
          return unless block_attached?(receiver)
          add_finding(
            node,
            message: "Use `.min_by { }` instead of `.sort_by { }.first` to find minimum in O(n)",
            speedup: "O(n log n) sort to O(n) single pass, no intermediate array"
          )
        when [:sort_by, :last]
          return unless block_attached?(receiver)
          add_finding(
            node,
            message: "Use `.max_by { }` instead of `.sort_by { }.last` to find maximum in O(n)",
            speedup: "O(n log n) sort to O(n) single pass, no intermediate array"
          )
        end
      end
    end
  end
end
