# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: str =~ /pattern/ or /pattern/.match(str) for boolean -> str.match?(/pattern/)
    #
    # When the result of =~ or .match is only used for truthiness (in if/unless/ternary),
    # using .match? avoids creating a MatchData object.
    #
    # Example:
    #   # Bad - creates MatchData object
    #   if str =~ /pattern/
    #   if /pattern/.match(str)
    #
    #   # Good - returns boolean without allocation
    #   if str.match?(/pattern/)
    class RegexpMatch < Base
      self.pattern_id = :regexp_match
      self.optimization_type = :allocation

      def initialize(file_path)
        super
        @in_boolean_context = false
      end

      # Track boolean contexts: if conditions
      def visit_if_node(node)
        visit_in_boolean_context(node.predicate)
        node.statements&.accept(self)
        node.subsequent&.accept(self)
      end

      # Track boolean contexts: unless conditions
      def visit_unless_node(node)
        visit_in_boolean_context(node.predicate)
        node.statements&.accept(self)
        node.else_clause&.accept(self)
      end

      # Track boolean contexts: while conditions
      def visit_while_node(node)
        visit_in_boolean_context(node.predicate)
        node.statements&.accept(self)
      end

      # Track boolean contexts: until conditions
      def visit_until_node(node)
        visit_in_boolean_context(node.predicate)
        node.statements&.accept(self)
      end

      # Track boolean contexts: ternary operator condition
      def visit_ternary_node(node)
        visit_in_boolean_context(node.predicate)
        node.true_expression&.accept(self)
        node.false_expression&.accept(self)
      end

      # Track boolean contexts: && and || operators
      def visit_and_node(node)
        visit_in_boolean_context(node.left)
        visit_in_boolean_context(node.right)
      end

      def visit_or_node(node)
        visit_in_boolean_context(node.left)
        visit_in_boolean_context(node.right)
      end

      def visit_call_node(node)
        super

        if @in_boolean_context
          check_regexp_match(node)
        end
      end

      # Detect =~ operator (str =~ /pattern/ or /pattern/ =~ str)
      def visit_match_last_line_node(node)
        return unless @in_boolean_context

        add_regexp_finding(node)
      end

      def visit_match_write_node(node)
        return unless @in_boolean_context

        add_regexp_finding(node)
      end

      private

      def visit_in_boolean_context(node)
        return unless node

        with_context(:@in_boolean_context, true) do
          node.accept(self)
        end
      end

      def check_regexp_match(node)
        # Check for =~ operator
        if node.name == :=~
          add_regexp_finding(node)
          return
        end

        # Check for .match(str) without block
        if node.name == :match && !block_attached?(node)
          # Verify it has arguments (not just calling match on something)
          return unless node.arguments&.arguments&.any?

          add_regexp_finding(node)
        end
      end

      def add_regexp_finding(node)
        add_finding(
          node,
          message: "Use `.match?` instead of `=~` or `.match` when only checking for a match",
          speedup: "Avoids creating MatchData object"
        )
      end
    end
  end
end
