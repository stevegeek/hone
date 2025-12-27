# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: str.sub(/^prefix/, '') -> str.delete_prefix('prefix')
    #
    # delete_prefix is a specialized method that avoids the regex engine overhead.
    # It's approximately 2x faster for this common use case.
    class StringDeletePrefix < Base
      self.pattern_id = :string_delete_prefix
      self.optimization_type = :cpu

      def visit_call_node(node)
        super

        return unless node.name == :sub

        args = node.arguments&.arguments
        return unless args&.size == 2

        first_arg = args[0]
        second_arg = args[1]

        # Check if first arg is a regex starting with ^
        return unless first_arg.is_a?(Prism::RegularExpressionNode)
        return unless second_arg.is_a?(Prism::StringNode) && second_arg.content.empty?

        pattern = first_arg.content
        return unless pattern.start_with?("^")

        # Extract the literal prefix (after ^)
        prefix = pattern[1..]

        # Only suggest for simple literal prefixes (no regex metacharacters)
        return unless simple_literal?(prefix)

        add_finding(
          node,
          message: "Use `.delete_prefix('#{prefix}')` instead of `.sub(/^#{prefix}/, '')`",
          speedup: "Avoids regex engine overhead"
        )
      end

      private

      def simple_literal?(str)
        # Check that the string doesn't contain regex metacharacters
        # that would change its meaning
        !str.match?(/[.+*?\[\](){}|\\$]/)
      end
    end
  end
end
