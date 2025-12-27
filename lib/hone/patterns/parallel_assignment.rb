# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: Sequential array index assignments -> parallel assignment
    #
    # When assigning multiple variables from sequential array indices (0, 1, 2...),
    # Ruby's parallel assignment syntax is more idiomatic and can be slightly faster
    # as it avoids multiple array access operations.
    #
    # Example:
    #   # Before
    #   a = arr[0]
    #   b = arr[1]
    #   c = arr[2]
    #
    #   # After
    #   a, b, c = arr
    #
    # Impact: Minor performance improvement, but more idiomatic Ruby
    class ParallelAssignment < Base
      self.pattern_id = :parallel_assignment
      self.optimization_type = :cpu

      def visit_statements_node(node)
        check_sequential_assignments(node.body)
        super
      end

      def visit_begin_node(node)
        check_sequential_assignments(node.statements&.body || [])
        super
      end

      private

      def check_sequential_assignments(statements)
        return if statements.nil? || statements.size < 2

        i = 0
        while i < statements.size
          sequence = find_assignment_sequence(statements, i)

          if sequence.size >= 2
            report_sequence(sequence)
            i += sequence.size
          else
            i += 1
          end
        end
      end

      def find_assignment_sequence(statements, start_index)
        sequence = []
        array_name = nil
        expected_index = 0

        (start_index...statements.size).each do |i|
          stmt = statements[i]
          break unless stmt.is_a?(Prism::LocalVariableWriteNode)

          array_access = extract_array_access(stmt.value)
          break unless array_access

          name, index = array_access

          if sequence.empty?
            array_name = name
            expected_index = index
          end

          break unless name == array_name && index == expected_index

          sequence << stmt
          expected_index += 1
        end

        sequence
      end

      def extract_array_access(node)
        return nil unless node.is_a?(Prism::CallNode)
        return nil unless node.name == :[]

        args = node.arguments&.arguments
        return nil unless args&.size == 1

        index_node = args.first
        return nil unless index_node.is_a?(Prism::IntegerNode)

        index = index_node.value
        return nil if index.negative?

        receiver = node.receiver
        array_name = extract_variable_name(receiver)
        return nil unless array_name

        [array_name, index]
      end

      def extract_variable_name(node)
        case node
        when Prism::LocalVariableReadNode
          node.name
        when Prism::InstanceVariableReadNode
          node.name
        when Prism::ClassVariableReadNode
          node.name
        when Prism::GlobalVariableReadNode
          node.name
        end
      end

      def report_sequence(sequence)
        var_names = sequence.map(&:name).join(", ")
        array_access = sequence.first.value
        array_name = extract_variable_name(array_access.receiver)

        add_finding(
          sequence.first,
          message: "Use parallel assignment `#{var_names} = #{array_name}` instead of sequential array index assignments",
          speedup: "Minor, but more idiomatic"
        )
      end
    end
  end
end
