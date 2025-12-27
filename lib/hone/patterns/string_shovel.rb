# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: str = str + other -> str << other
    #
    # When reassigning a local variable to itself plus another string,
    # using the shovel operator (<<) avoids creating a new string object.
    # The + operator always creates a new string, while << mutates in place.
    #
    # Example:
    #   # Before - creates new string
    #   str = str + other
    #   str = str + "suffix"
    #
    #   # After - mutates in place
    #   str << other
    #   str << "suffix"
    #
    # Note: Only safe when the original string can be mutated (not frozen,
    # not shared with other references that expect the original value).
    #
    # Impact: Avoids allocating a new string object
    class StringShovel < Base
      self.pattern_id = :string_shovel
      self.optimization_type = :allocation

      def visit_local_variable_write_node(node)
        super

        check_string_reassignment(node, node.name)
      end

      private

      def check_string_reassignment(node, var_name)
        value = node.value
        return unless value.is_a?(Prism::CallNode)
        return unless value.name == :+

        receiver = value.receiver
        return unless matches_variable?(receiver, var_name)

        args = value.arguments&.arguments
        return unless args&.size == 1
        return unless likely_string?(args.first)

        add_finding(
          node,
          message: "Use `#{var_name} << ...` instead of `#{var_name} = #{var_name} + ...` to avoid creating a new string",
          speedup: "Avoids creating new string"
        )
      end

      def matches_variable?(node, var_name)
        node.is_a?(Prism::LocalVariableReadNode) && node.name == var_name
      end

      def likely_string?(node)
        case node
        when Prism::StringNode, Prism::InterpolatedStringNode
          true
        when Prism::CallNode
          %i[to_s to_str inspect].include?(node.name)
        when Prism::LocalVariableReadNode
          # Could be a string, we'll suggest the optimization
          # User can decide if it's appropriate
          true
        else
          false
        end
      end
    end
  end
end
