# frozen_string_literal: true

module Hone
  module Patterns
    # Pattern: hash = hash.merge(other) -> hash.merge!(other)
    #
    # Reassigning to the same variable after merge creates a new hash.
    # merge! mutates in place, avoiding allocation.
    class HashMergeBang < Base
      self.pattern_id = :hash_merge_bang
      self.optimization_type = :allocation

      def visit_local_variable_write_node(node)
        super

        # Look for: x = x.merge(...)
        value = node.value
        return unless value.is_a?(Prism::CallNode)
        return unless value.name == :merge

        receiver = value.receiver
        return unless receiver.is_a?(Prism::LocalVariableReadNode)
        return unless receiver.name == node.name

        add_finding(
          node,
          message: "Use `.merge!` instead of `#{node.name} = #{node.name}.merge(...)` to avoid creating new hash",
          speedup: "Avoids creating new hash, mutates in place"
        )
      end
    end
  end
end
