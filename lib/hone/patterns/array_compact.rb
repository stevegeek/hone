# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: array.reject { |x| x.nil? } -> array.compact
    #          array.select { |x| !x.nil? } -> array.compact
    #
    # compact is implemented in C and optimized for removing nil values.
    # Using reject/select with a block for nil checking is slower and less clear.
    class ArrayCompact < Base
      self.pattern_id = :array_compact
      self.optimization_type = :cpu

      def visit_call_node(node)
        super

        return unless %i[reject select].include?(node.name)
        return unless block_attached?(node)

        block = node.block
        return unless block.is_a?(Prism::BlockNode)

        if node.name == :reject && reject_nil_pattern?(block)
          add_finding(
            node,
            message: "Use `.compact` instead of `.reject { |x| x.nil? }` for optimized nil removal",
            speedup: "Uses optimized C implementation"
          )
        elsif node.name == :select && select_not_nil_pattern?(block)
          add_finding(
            node,
            message: "Use `.compact` instead of `.select { |x| !x.nil? }` for optimized nil removal",
            speedup: "Uses optimized C implementation"
          )
        end
      end

      private

      # Detects: { |x| x.nil? }
      def reject_nil_pattern?(block)
        return false unless single_block_param?(block)

        body = block.body
        return false unless body.is_a?(Prism::StatementsNode)
        return false unless body.body.size == 1

        statement = body.body.first
        nil_check_on_param?(statement, block_param_name(block))
      end

      # Detects: { |x| !x.nil? }
      def select_not_nil_pattern?(block)
        return false unless single_block_param?(block)

        body = block.body
        return false unless body.is_a?(Prism::StatementsNode)
        return false unless body.body.size == 1

        statement = body.body.first
        negated_nil_check_on_param?(statement, block_param_name(block))
      end

      def single_block_param?(block)
        params = block.parameters
        return false unless params.is_a?(Prism::BlockParametersNode)

        parameters = params.parameters
        return false unless parameters.is_a?(Prism::ParametersNode)
        return false unless parameters.requireds.size == 1
        return false unless parameters.optionals.empty?
        return false unless parameters.rest.nil?
        return false unless parameters.keywords.empty?

        true
      end

      def block_param_name(block)
        block.parameters.parameters.requireds.first.name
      end

      # Checks if statement is: param.nil?
      def nil_check_on_param?(statement, param_name)
        return false unless statement.is_a?(Prism::CallNode)
        return false unless statement.name == :nil?
        return false unless statement.arguments.nil?

        receiver = statement.receiver
        return false unless receiver.is_a?(Prism::LocalVariableReadNode)

        receiver.name == param_name
      end

      # Checks if statement is: !param.nil?
      def negated_nil_check_on_param?(statement, param_name)
        # Check for !(...) pattern
        return false unless statement.is_a?(Prism::CallNode)
        return false unless statement.name == :!
        return false unless statement.receiver

        nil_check_on_param?(statement.receiver, param_name)
      end
    end
  end
end
