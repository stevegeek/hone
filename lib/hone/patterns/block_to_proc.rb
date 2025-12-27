# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: array.map { |x| x.to_s } -> array.map(&:to_s)
    #
    # When a block simply calls a single method on its parameter with no
    # arguments, the Symbol#to_proc shorthand is more idiomatic and slightly
    # more efficient.
    #
    # Examples:
    #   # Bad: verbose block
    #   array.map { |x| x.to_s }
    #   array.select { |item| item.valid? }
    #   # Good: Symbol#to_proc shorthand
    #   array.map(&:to_s)
    #   array.select(&:valid?)
    class BlockToProc < Base
      self.pattern_id = :block_to_proc
      self.optimization_type = :cpu

      # Methods that commonly take blocks and can use Symbol#to_proc
      APPLICABLE_METHODS = %i[
        map collect select find_all reject detect find
        any? all? none? one? sort_by group_by partition
        max_by min_by minmax_by count take_while drop_while
        filter filter_map
      ].freeze

      def visit_call_node(node)
        super

        return unless APPLICABLE_METHODS.include?(node.name)
        return unless node.block.is_a?(Prism::BlockNode)

        block = node.block
        return unless single_param_block?(block)
        return unless block_body_is_single_method_call?(block)

        param_name = extract_single_param_name(block)
        method_name = extract_called_method_name(block)

        return unless param_name && method_name

        add_finding(
          node,
          message: "Use `.#{node.name}(&:#{method_name})` instead of `.#{node.name} { |#{param_name}| #{param_name}.#{method_name} }` for Symbol#to_proc shorthand",
          speedup: "Minor, but more idiomatic Ruby"
        )
      end

      private

      def single_param_block?(block)
        parameters = block.parameters
        return false unless parameters.is_a?(Prism::BlockParametersNode)
        return false unless parameters.parameters.is_a?(Prism::ParametersNode)

        params = parameters.parameters
        params.requireds.size == 1 &&
          params.optionals.empty? &&
          params.rest.nil? &&
          params.keywords.empty? &&
          params.keyword_rest.nil? &&
          params.block.nil?
      end

      def block_body_is_single_method_call?(block)
        body = block.body
        return false unless body.is_a?(Prism::StatementsNode)
        return false unless body.body.size == 1

        statement = body.body.first
        return false unless statement.is_a?(Prism::CallNode)

        # The receiver should be a local variable read matching the block param
        receiver = statement.receiver
        return false unless receiver.is_a?(Prism::LocalVariableReadNode)

        # The call should have no arguments
        return false if statement.arguments && !statement.arguments.arguments.empty?

        # The call should not have its own block
        return false if statement.block

        true
      end

      def extract_single_param_name(block)
        param = block.parameters.parameters.requireds.first
        case param
        when Prism::RequiredParameterNode
          param.name
        end
      end

      def extract_called_method_name(block)
        statement = block.body.body.first
        receiver = statement.receiver

        # Verify the receiver matches the block parameter
        param_name = extract_single_param_name(block)
        return nil unless receiver.name == param_name

        statement.name
      end
    end
  end
end
