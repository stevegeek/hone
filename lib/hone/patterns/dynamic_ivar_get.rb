# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: instance_variable_get("@#{name}")
    #
    # Often paired with dynamic instance_variable_set. Suggests the code
    # is using ivars as a dynamic key-value store, which hurts JIT.
    #
    # Impact: Significant with YJIT, none without
    class DynamicIvarGet < Base
      self.pattern_id = :dynamic_ivar_get
      self.optimization_type = :jit

      def visit_call_node(node)
        super

        return unless node.name == :instance_variable_get

        first_arg = node.arguments&.arguments&.first
        return unless first_arg
        return unless first_arg.is_a?(Prism::InterpolatedStringNode) ||
          first_arg.is_a?(Prism::LocalVariableReadNode)

        add_finding(
          node,
          message: "Dynamic instance_variable_get suggests ivars used as key-value store. Use a Hash instead for better YJIT performance.",
          speedup: "Significant with YJIT, none without"
        )
      end
    end
  end
end
