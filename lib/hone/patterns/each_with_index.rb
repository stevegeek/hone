# frozen_string_literal: true

require "set"

module Hone
  module Patterns
    # Pattern: array.each_with_index { |item, i| ... } when index or element unused
    #
    # When using each_with_index but only using the element (not the index),
    # use plain .each instead to avoid index tracking overhead.
    #
    # When using each_with_index but only using the index (not the element),
    # use array.size.times { |i| ... } instead for clarity and efficiency.
    #
    # Examples:
    #   # Bad: index `i` is never used
    #   array.each_with_index { |item, i| puts item }
    #   # Good: use plain each
    #   array.each { |item| puts item }
    #
    #   # Bad: element `item` is never used
    #   array.each_with_index { |item, i| puts i }
    #   # Good: use times
    #   array.size.times { |i| puts i }
    class EachWithIndex < Base
      self.pattern_id = :each_with_index
      self.optimization_type = :cpu

      def visit_call_node(node)
        super
        return unless node.name == :each_with_index && node.block.is_a?(Prism::BlockNode)

        check_block_parameter_usage(node)
      end

      private

      def check_block_parameter_usage(node)
        block = node.block
        parameters = block.parameters

        # If no parameters or not the expected structure, skip
        return unless parameters.is_a?(Prism::BlockParametersNode)
        return unless parameters.parameters.is_a?(Prism::ParametersNode)

        params = parameters.parameters
        requireds = params.requireds

        # We expect two required parameters for each_with_index: |element, index|
        return unless requireds.size == 2

        element_param = requireds[0]
        index_param = requireds[1]

        # Get parameter names
        element_name = extract_param_name(element_param)
        index_name = extract_param_name(index_param)

        return unless element_name && index_name

        # Collect all local variable reads in the block body
        used_locals = collect_local_variable_reads(block.body)

        element_used = used_locals.include?(element_name)
        index_used = used_locals.include?(index_name)

        if !index_used && element_used
          add_finding(
            node,
            message: "Index parameter `#{index_name}` is not used. Use `.each` instead of `.each_with_index` to avoid index tracking overhead.",
            speedup: "Minor, avoids index tracking overhead"
          )
        elsif !element_used && index_used
          add_finding(
            node,
            message: "Element parameter `#{element_name}` is not used. Consider using `.size.times { |#{index_name}| }` instead of `.each_with_index` for clarity.",
            speedup: "Minor, avoids index tracking overhead"
          )
        elsif !element_used && !index_used
          add_finding(
            node,
            message: "Neither element nor index parameters are used. Consider using `.size.times` or `.each` depending on intent.",
            speedup: "Minor, avoids index tracking overhead"
          )
        end
      end

      def extract_param_name(param)
        case param
        when Prism::RequiredParameterNode
          param.name
        end
      end

      def collect_local_variable_reads(node)
        collector = LocalVariableCollector.new
        node&.accept(collector)
        collector.used_names
      end

      # Helper visitor to collect all local variable read references
      class LocalVariableCollector < Prism::Visitor
        attr_reader :used_names

        def initialize
          @used_names = Set.new
        end

        def visit_local_variable_read_node(node)
          @used_names << node.name
          super
        end
      end
    end
  end
end
