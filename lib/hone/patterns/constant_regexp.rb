# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: /pattern/ inside method -> extract to constant
    #
    # Regexp literals are recompiled each time the code is executed.
    # Extracting to a constant compiles the regexp once at load time.
    #
    # Example:
    #   # Bad - recompiles regexp on each call
    #   def process(str)
    #     str.gsub(/\s+/, ' ')
    #   end
    #
    #   # Good - compiled once at load time
    #   WHITESPACE = /\s+/
    #   def process(str)
    #     str.gsub(WHITESPACE, ' ')
    #   end
    #
    # Note: Only flags regexps without interpolation, as interpolated regexps
    # may need to be dynamic.
    class ConstantRegexp < Base
      self.pattern_id = :constant_regexp
      self.optimization_type = :allocation

      def initialize(file_path)
        super
        @in_method = false
      end

      # Track when we're inside a method definition
      def visit_def_node(node)
        with_context(:@in_method, true) { super }
      end

      # Detect static regexp literals inside methods
      def visit_regular_expression_node(node)
        super

        return unless @in_method

        # Skip if the regexp is very short/simple - the overhead is minimal
        # and extracting trivially small regexps hurts readability
        content = node.content
        return if content.length < 3

        add_finding(
          node,
          message: "Consider extracting regexp `/#{escape_for_message(content)}/` to a constant",
          speedup: "Avoids recompiling regexp on each call"
        )
      end

      # Skip interpolated regexps as they may need to be dynamic
      def visit_interpolated_regular_expression_node(node)
        # Don't call super - we intentionally don't flag interpolated regexps
        # as they often need to be dynamic
      end

      private

      def escape_for_message(content)
        # Truncate long regexps and escape for display
        if content.length > 20
          content[0..17] + "..."
        else
          content
        end
      end
    end
  end
end
