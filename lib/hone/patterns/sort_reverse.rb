# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: array.sort.reverse -> array.sort { |a, b| b <=> a }
    #
    # Calling .sort.reverse creates an intermediate sorted array, then
    # reverses it. Sorting with a descending comparator avoids the
    # intermediate array allocation.
    #
    # Example:
    #   # Bad - creates intermediate array
    #   array.sort.reverse
    #
    #   # Good - sorts in descending order directly
    #   array.sort { |a, b| b <=> a }
    #
    # Note: For sort_by, use: array.sort_by { |x| -x.value } for numeric values
    class SortReverse < Base
      self.pattern_id = :sort_reverse
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        # Look for: .reverse where receiver is .sort or .sort_by
        return unless node.name == :reverse

        receiver = node.receiver
        return unless receiver.is_a?(Prism::CallNode)

        case receiver.name
        when :sort
          # .sort.reverse -> .sort { |a, b| b <=> a }
          add_finding(
            node,
            message: "Use `.sort { |a, b| b <=> a }` instead of `.sort.reverse` to avoid intermediate array",
            speedup: "Avoids creating intermediate sorted array"
          )
        when :sort_by
          # .sort_by { }.reverse -> consider negating the sort key
          return unless block_attached?(receiver)

          add_finding(
            node,
            message: "Consider negating the sort key in `.sort_by` instead of calling `.reverse`",
            speedup: "Avoids creating intermediate sorted array"
          )
        end
      end
    end
  end
end
