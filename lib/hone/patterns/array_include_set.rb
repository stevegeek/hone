# frozen_string_literal: true

require "set"

module Hone
  module Patterns
    # Pattern: CONSTANT.include?(x) -> consider Set for repeated lookups
    #
    # Array#include? is O(n) for each lookup.
    # If performing repeated lookups on a constant array, converting to Set gives O(1) lookups.
    #
    # We only flag when receiver is:
    # - A constant (e.g., ALLOWED_METHODS.include?)
    # - An array literal (e.g., [:get, :post].include?)
    #
    # We skip when:
    # - Receiver is a Hash constant (Hash#include? is O(1))
    # - Receiver is already a Set (detected via .to_set in definition)
    #
    # This avoids false positives with String#include? which is already optimal.
    class ArrayIncludeSet < Base
      self.pattern_id = :array_include_set
      self.optimization_type = :cpu

      def initialize(file_path)
        super
        @hash_constants = Set.new
        @set_constants = Set.new
      end

      # First pass: collect Hash and Set constant definitions
      def visit_constant_write_node(node)
        super
        check_constant_definition(node.name.to_s, node.value)
      end

      def visit_constant_path_write_node(node)
        super
        # For Foo::BAR = value, get the constant name
        const_name = extract_constant_name(node.target)
        check_constant_definition(const_name, node.value) if const_name
      end

      def visit_call_node(node)
        super

        # Look for: .include?(x) with one argument
        return unless node.name == :include?
        return unless node.arguments&.arguments&.size == 1

        receiver = node.receiver
        return unless receiver

        # Only flag constants (likely Array constants) or array literals
        is_constant = receiver.is_a?(Prism::ConstantReadNode) ||
                      receiver.is_a?(Prism::ConstantPathNode)
        is_array_literal = receiver.is_a?(Prism::ArrayNode)

        return unless is_constant || is_array_literal

        # Skip if receiver is a constant we identified as Hash or Set
        if is_constant
          const_name = extract_constant_name(receiver)
          return if const_name && (@hash_constants.include?(const_name) || @set_constants.include?(const_name))
        end

        # Skip if receiver is a known hash method chain (handled by hash_keys_include)
        if receiver.is_a?(Prism::CallNode)
          return if receiver.name == :keys || receiver.name == :values
        end

        add_finding(
          node,
          message: "Consider using Set instead of Array#include? for repeated lookups",
          speedup: "O(1) vs O(n) for repeated lookups"
        )
      end

      private

      def extract_constant_name(node)
        case node
        when Prism::ConstantReadNode
          node.name.to_s
        when Prism::ConstantPathNode
          # For Foo::Bar::BAZ, just get "BAZ"
          node.name.to_s
        else
          nil
        end
      end

      def check_constant_definition(name, value)
        return unless name && value

        # Check for Hash literal: { key: value }
        if value.is_a?(Prism::HashNode)
          @hash_constants << name
          return
        end

        # Check for method chain ending in .freeze on a Hash or .to_set
        if value.is_a?(Prism::CallNode)
          check_call_chain(name, value)
        end
      end

      def check_call_chain(name, node)
        # Follow the chain: { }.freeze or [...].to_set.freeze or Set[...].freeze
        receiver = node.receiver

        # Check for .to_set anywhere in chain
        if node.name == :to_set
          @set_constants << name
          return
        end

        # Check for Set[...] or Set.new(...) syntax
        if set_constructor?(node)
          @set_constants << name
          return
        end

        # Check for Hash literal with .freeze
        if node.name == :freeze && receiver.is_a?(Prism::HashNode)
          @hash_constants << name
          return
        end

        # Recurse into receiver if it's another call
        if receiver.is_a?(Prism::CallNode)
          check_call_chain(name, receiver)
        elsif receiver.is_a?(Prism::HashNode)
          @hash_constants << name
        end
      end

      # Detect Set[...] or Set.new(...) constructor patterns
      def set_constructor?(node)
        receiver = node.receiver
        return false unless receiver.is_a?(Prism::ConstantReadNode)
        return false unless receiver.name == :Set

        # Set[...] or Set.new(...)
        node.name == :[] || node.name == :new
      end
    end
  end
end
