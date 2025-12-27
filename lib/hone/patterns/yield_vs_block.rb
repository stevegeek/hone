# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: block.call -> yield when method has &block parameter
    #
    # When a method accepts a block with `&block`, calling `block.call` is slower
    # than using `yield`. The `&block` syntax converts the block to a Proc object,
    # which has overhead. Using `yield` avoids this Proc allocation when the block
    # is only called (not stored or passed elsewhere).
    #
    # Example:
    #   # Before - allocates Proc
    #   def process(&block)
    #     block.call(value)
    #   end
    #
    #   # After - no Proc allocation
    #   def process
    #     yield(value)
    #   end
    #
    # Impact: Avoids Proc allocation
    class YieldVsBlock < Base
      self.pattern_id = :yield_vs_block
      self.optimization_type = :cpu

      def initialize(file_path)
        super
        @block_param_name = nil
      end

      def visit_def_node(node)
        block_param = find_block_parameter(node.parameters)

        if block_param
          with_context(:@block_param_name, block_param) { super }
        else
          super
        end
      end

      def visit_call_node(node)
        super

        return unless @block_param_name
        return unless node.name == :call

        receiver = node.receiver
        return unless receiver.is_a?(Prism::LocalVariableReadNode)
        return unless receiver.name == @block_param_name

        add_finding(
          node,
          message: "Use `yield` instead of `#{@block_param_name}.call` to avoid Proc allocation",
          speedup: "Avoids Proc allocation"
        )
      end

      private

      def find_block_parameter(params)
        return nil unless params

        block = params.block
        return nil unless block.is_a?(Prism::BlockParameterNode)

        block.name
      end
    end
  end
end
