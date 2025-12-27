# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: String concatenation (`+=`) inside a loop -> use `<<` or array join
    #
    # Each string `+=` operation creates a new string object, copying all previous
    # content. In a loop, this leads to O(n^2) memory allocations and copies.
    # Using `<<` mutates the string in place, avoiding allocations.
    #
    # Example:
    #   # Bad - O(n^2) allocations
    #   items.each { |item| result += item.to_s }
    #
    #   # Good - O(n) with in-place mutation
    #   items.each { |item| result << item.to_s }
    #
    #   # Good - collect and join once
    #   result = items.map(&:to_s).join
    #
    # Impact: Significant in tight loops, avoids O(n^2) string copying
    class StringConcatInLoop < Base
      self.pattern_id = :string_concat_in_loop
      self.optimization_type = :allocation

      LOOP_METHODS = %i[each each_with_index each_with_object map collect
        times upto downto step loop].freeze

      def initialize(file_path)
        super
        @in_loop = false
      end

      # Track when we enter/exit while loops
      def visit_while_node(node)
        with_context(:@in_loop, true) { super }
      end

      # Track when we enter/exit until loops
      def visit_until_node(node)
        with_context(:@in_loop, true) { super }
      end

      # Track when we enter/exit for loops
      def visit_for_node(node)
        with_context(:@in_loop, true) { super }
      end

      # Handle block-based loops (.each, .times, .map, loop, etc.)
      def visit_call_node(node)
        if loop_method?(node) && node.block
          with_context(:@in_loop, true) { super }
        else
          super
        end
      end

      # Detect local variable += (e.g., str += "x")
      def visit_local_variable_operator_write_node(node)
        check_string_concat(node)
        super
      end

      # Detect instance variable += (e.g., @str += "x")
      def visit_instance_variable_operator_write_node(node)
        check_string_concat(node)
        super
      end

      # Detect class variable += (e.g., @@str += "x")
      def visit_class_variable_operator_write_node(node)
        check_string_concat(node)
        super
      end

      # Detect global variable += (e.g., $str += "x")
      def visit_global_variable_operator_write_node(node)
        check_string_concat(node)
        super
      end

      private

      def loop_method?(node)
        LOOP_METHODS.include?(node.name)
      end

      def check_string_concat(node)
        return unless @in_loop
        return unless node.binary_operator == :+
        return unless string_value?(node.value)

        add_finding(
          node,
          message: "Use `<<` instead of `+=` for string concatenation in loops to avoid allocations",
          speedup: "Significant in tight loops, avoids O(n^2) string copying"
        )
      end

      def string_value?(node)
        case node
        when Prism::StringNode, Prism::InterpolatedStringNode
          true
        when Prism::CallNode
          # Method calls that likely return strings (e.g., to_s, inspect, to_str)
          %i[to_s to_str inspect].include?(node.name)
        else
          # For other node types (variables, etc.), we can't be sure
          # but += with + operator is most commonly used for strings
          # We'll be conservative and only match known string types
          false
        end
      end
    end
  end
end
