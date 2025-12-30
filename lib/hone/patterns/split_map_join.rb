# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: str.split(x).map { }.join(x) -> consider gsub
    #
    # This pattern allocates:
    # 1. An array from split
    # 2. A new array from map
    # 3. New strings for each element
    # 4. Final joined string
    #
    # Often can be replaced with gsub which avoids intermediate arrays.
    #
    # Example:
    #   # Before - 4 allocations
    #   name.split('-').map { |s| s.capitalize }.join('-')
    #
    #   # After - 1 allocation
    #   name.gsub(/(?:^|-)[a-z]/) { |m| m.upcase }
    #
    class SplitMapJoin < Base
      self.pattern_id = :split_map_join
      self.optimization_type = :allocation

      def visit_call_node(node)
        super

        # Look for .join(...) call
        return unless node.name == :join

        # Check if receiver is .map { } or .map(&:...)
        map_node = node.receiver
        return unless map_node.is_a?(Prism::CallNode)
        return unless map_node.name == :map

        # Check if map's receiver is .split(...)
        split_node = map_node.receiver
        return unless split_node.is_a?(Prism::CallNode)
        return unless split_node.name == :split

        add_finding(
          node,
          message: "Consider using `gsub` instead of `split().map{}.join()` to avoid intermediate array allocations",
          speedup: "Avoids 2 array allocations"
        )
      end
    end
  end
end
