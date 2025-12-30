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
    #
    # NOT flagged (result is captured for later use):
    #   if m = str.match(/pattern/)
    #     m["capture"]  # MatchData is needed
    #   end
    #
    # NOT flagged (uses $1, $2, etc. match globals):
    #   if string =~ /pattern/
    #     use($1)  # Needs match data side effect
    #   end
    #
    # NOT flagged (uses $~ MatchData global):
    #   if key =~ /pattern/
    #     $~.pre_match  # Needs MatchData object
    #   end
    class RegexpMatch < Base
      self.pattern_id = :regexp_match
      self.optimization_type = :allocation

      def initialize(file_path)
        super
        @in_boolean_context = false
        @in_assignment = false
        @uses_numbered_reference = false
      end

      # Track boolean contexts: if conditions
      # Check body AND else/elsif for $1, $2, $~ usage before visiting predicate
      def visit_if_node(node)
        with_match_reference_check_for_nodes(node.statements, node.subsequent) do
          visit_in_boolean_context(node.predicate)
        end
        node.statements&.accept(self)
        node.subsequent&.accept(self)
      end

      # Track boolean contexts: unless conditions
      # Check both body AND else clause for $1, $2, $~ usage before visiting predicate
      def visit_unless_node(node)
        with_match_reference_check_for_nodes(node.statements, node.else_clause) do
          visit_in_boolean_context(node.predicate)
        end
        node.statements&.accept(self)
        node.else_clause&.accept(self)
      end

      # Track boolean contexts: while conditions
      def visit_while_node(node)
        visit_in_boolean_context(node.predicate)
        node.statements&.accept(self)
      end

      # For blocks, check if ANY statement uses match globals
      # This handles patterns like:
      #   each_key do |key|
      #     next unless key =~ /pattern/
      #     next unless $~.pre_match == other  # $~ used in sibling statement
      #   end
      def visit_block_node(node)
        with_match_reference_check_for_nodes(node.body) do
          node.body&.accept(self)
        end
      end

      # Also handle lambda/proc bodies
      def visit_lambda_node(node)
        with_match_reference_check_for_nodes(node.body) do
          node.body&.accept(self)
        end
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
      # Check both sides for match references (e.g., `match(...) && $1`)
      def visit_and_node(node)
        with_match_reference_check_for_nodes(node.left, node.right) do
          visit_in_boolean_context(node.left)
          visit_in_boolean_context(node.right)
        end
      end

      def visit_or_node(node)
        with_match_reference_check_for_nodes(node.left, node.right) do
          visit_in_boolean_context(node.left)
          visit_in_boolean_context(node.right)
        end
      end

      # Track assignment contexts: if m = pattern.match(str)
      # When match result is assigned, the MatchData is likely needed
      def visit_local_variable_write_node(node)
        with_context(:@in_assignment, true) do
          node.value&.accept(self)
        end
      end

      # Also track instance variable assignment: @m = pattern.match(str)
      def visit_instance_variable_write_node(node)
        with_context(:@in_assignment, true) do
          node.value&.accept(self)
        end
      end

      # Also track class variable assignment: @@m = pattern.match(str)
      def visit_class_variable_write_node(node)
        with_context(:@in_assignment, true) do
          node.value&.accept(self)
        end
      end

      def visit_call_node(node)
        super

        if @in_boolean_context && !@in_assignment && !@uses_numbered_reference
          check_regexp_match(node)
        end
      end

      # Detect =~ operator (str =~ /pattern/ or /pattern/ =~ str)
      def visit_match_last_line_node(node)
        return unless @in_boolean_context
        return if @in_assignment
        return if @uses_numbered_reference

        add_regexp_finding(node)
      end

      def visit_match_write_node(node)
        # MatchWriteNode is for =~ with named captures that auto-assign
        # e.g., /(?<name>pattern)/ =~ str creates local variable `name`
        # Since it creates variables, the match data IS being used
        # Don't flag these
      end

      private

      def visit_in_boolean_context(node)
        return unless node

        with_context(:@in_boolean_context, true) do
          node.accept(self)
        end
      end

      # Check if any of the given nodes contain match data references ($1, $2, $~, etc.)
      # Used to detect when =~ is used with match globals, which need the match side effect
      # Preserves outer scope flag - if already true, stays true (block scope sets it for all inner nodes)
      def with_match_reference_check_for_nodes(*nodes)
        old_value = @uses_numbered_reference
        # OR with existing value - if outer scope already found match refs, preserve that
        @uses_numbered_reference = @uses_numbered_reference || nodes.compact.any? { |n| contains_match_reference?(n) }
        yield
      ensure
        @uses_numbered_reference = old_value
      end

      def contains_match_reference?(node)
        return false unless node

        finder = MatchDataReferenceFinder.new
        node.accept(finder)
        finder.found?
      end

      # Visitor to find match-related global variable reads in a subtree
      # Detects: $1, $2, ... (NumberedReferenceReadNode)
      #          $~         (GlobalVariableReadNode)
      #          $&, $`, $', $+ (BackReferenceReadNode)
      class MatchDataReferenceFinder < Prism::Visitor
        def initialize
          @found = false
        end

        def found?
          @found
        end

        # $1, $2, etc.
        def visit_numbered_reference_read_node(node)
          @found = true
        end

        # $& (matched string), $` (pre_match), $' (post_match), $+ (last capture)
        def visit_back_reference_read_node(node)
          @found = true
        end

        # $~ (MatchData object)
        def visit_global_variable_read_node(node)
          @found = true if node.name == :$~
        end

        # Override to stop visiting if already found (optimization)
        def visit(node)
          return if @found

          super
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
