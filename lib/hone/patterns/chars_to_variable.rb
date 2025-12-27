# frozen_string_literal: true

module Hone
  module Patterns
    # Approach 1: Simple scope-limited variable tracking
    #
    # Detects when .chars is assigned to a variable and then used in ways
    # that could be done directly on the string.
    #
    # @example Bad - allocates array just for indexing
    #   chars = str.chars
    #   chars[0]
    #   chars.length
    #   chars.each { |c| ... }
    #
    # @example Good - direct string operations
    #   str[0]
    #   str.length
    #   str.each_char { |c| ... }
    #
    class CharsToVariable < Base
      self.pattern_id = :chars_to_variable
      self.optimization_type = :allocation

      def initialize(file_path)
        super
        @scope_stack = []
      end

      # Track method scope
      def visit_def_node(node)
        with_scope { super }
      end

      # Track block scope
      def visit_block_node(node)
        with_scope { super }
      end

      # Track lambda scope
      def visit_lambda_node(node)
        with_scope { super }
      end

      # Track .chars assignments
      def visit_local_variable_write_node(node)
        super
        track_chars_assignment(node)
      end

      # Check for inefficient usage of tracked variables
      def visit_call_node(node)
        super
        check_inefficient_usage(node)
      end

      private

      def with_scope
        @scope_stack.push({})
        yield
      ensure
        @scope_stack.pop
      end

      def current_scope
        @scope_stack.last || {}
      end

      def track_chars_assignment(node)
        return unless node.value.is_a?(Prism::CallNode)
        return unless node.value.name == :chars
        return if node.value.arguments&.arguments&.any? # chars with args is different

        source_receiver = node.value.receiver
        return unless source_receiver # Need to know what .chars was called on

        current_scope[node.name] = {
          source_code: source_receiver.slice,
          assignment_line: node.location.start_line
        }
      end

      def check_inefficient_usage(node)
        return unless node.receiver.is_a?(Prism::LocalVariableReadNode)

        var_name = node.receiver.name
        info = current_scope[var_name]
        return unless info

        source = info[:source_code]

        case node.name
        when :[]
          add_finding(
            node,
            message: "Use `#{source}[...]` directly instead of `.chars` variable indexing",
            speedup: "Avoids allocating array of all characters"
          )
        when :length, :size
          add_finding(
            node,
            message: "Use `#{source}.length` directly instead of `.chars.length`",
            speedup: "Avoids allocating array of all characters"
          )
        when :each
          return unless block_attached?(node)

          add_finding(
            node,
            message: "Use `#{source}.each_char { }` instead of `.chars.each { }`",
            speedup: "~1.4x faster, no intermediate array"
          )
        when :first
          add_finding(
            node,
            message: "Use `#{source}[0]` instead of `.chars.first`",
            speedup: "Avoids allocating array of all characters"
          )
        when :last
          add_finding(
            node,
            message: "Use `#{source}[-1]` instead of `.chars.last`",
            speedup: "Avoids allocating array of all characters"
          )
        when :include?
          add_finding(
            node,
            message: "Use `#{source}.include?(...)` directly on string",
            speedup: "String#include? works without array allocation"
          )
        end
      end
    end
  end
end
