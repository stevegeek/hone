# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: @ivar ||= value (outside initialize)
    #
    # When an ivar is first assigned outside initialize, it changes the
    # object's shape at runtime. YJIT prefers stable shapes from creation.
    #
    # This pattern detects ||= with ivars outside of initialize methods.
    #
    # Impact: Moderate with YJIT, none without
    class LazyIvar < Base
      self.pattern_id = :lazy_ivar
      self.optimization_type = :jit

      def initialize(file_path)
        super
        @in_initialize = false
      end

      def visit_def_node(node)
        with_context(:@in_initialize, node.name == :initialize) { super }
      end

      def visit_instance_variable_or_write_node(node)
        super
        # @ivar ||= value pattern
        return if @in_initialize

        add_finding(
          node,
          message: "Lazy ivar initialization (||=) outside initialize causes shape transitions. Define #{node.name} = nil in initialize for better YJIT.",
          speedup: "Moderate with YJIT, none without"
        )
      end
    end
  end
end
