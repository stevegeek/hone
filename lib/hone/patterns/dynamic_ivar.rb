# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: instance_variable_set("@#{name}", value)
    #
    # Dynamic instance variable creation causes object shape transitions.
    # YJIT optimizes based on stable object shapes - when shapes change,
    # it must deoptimize. Use a Hash for dynamic data instead.
    #
    # Impact: Significant with YJIT, none without
    class DynamicIvar < Base
      self.pattern_id = :dynamic_ivar
      self.optimization_type = :jit

      def visit_call_node(node)
        super

        return unless node.name == :instance_variable_set

        first_arg = node.arguments&.arguments&.first
        return unless first_arg
        return unless dynamic_ivar_name?(first_arg)

        add_finding(
          node,
          message: "Dynamic instance_variable_set causes object shape transitions, hurting YJIT. Use a Hash for dynamic data instead.",
          speedup: "Significant with YJIT (2-3x), none without"
        )
      end

      private

      def dynamic_ivar_name?(node)
        # Interpolated string like "@#{name}"
        node.is_a?(Prism::InterpolatedStringNode) ||
          # String concatenation
          (node.is_a?(Prism::CallNode) && node.name == :+) ||
          # Variable (not a literal symbol/string)
          node.is_a?(Prism::LocalVariableReadNode)
      end
    end
  end
end
