# frozen_string_literal: true

require "prism"

module Hone
  # Pattern matchers for detecting optimization opportunities in Ruby AST.
  #
  # Each pattern class inherits from Base and implements visit_* methods
  # to detect specific anti-patterns using Prism's visitor interface.
  #
  # @example Creating a custom pattern
  #   class MyPattern < Base
  #     self.pattern_id = :my_pattern
  #     self.optimization_type = :cpu
  #
  #     def visit_call_node(node)
  #       super
  #       # detection logic here
  #     end
  #   end
  module Patterns
    @registered = []

    class << self
      attr_reader :registered

      def register(pattern_class)
        @registered << pattern_class
      end
    end

    class Base < Prism::Visitor
      def self.inherited(subclass)
        Patterns.register(subclass)
      end
      class << self
        attr_accessor :pattern_id, :optimization_type
      end

      def self.scan_file(path)
        result = Prism.parse_file(path)
        pattern = new(path)
        result.value.accept(pattern)
        pattern.findings
      end

      def initialize(file_path)
        @file_path = file_path
        @findings = []
      end

      attr_reader :findings

      def add_finding(node, message:, speedup: nil)
        @findings << Finding.new(
          file: @file_path,
          line: node.location.start_line,
          column: node.location.start_column,
          pattern_id: self.class.pattern_id,
          optimization_type: self.class.optimization_type,
          source: :hone,
          message: message,
          speedup: speedup,
          code: node.location.slice
        )
      end

      protected

      def block_attached?(call_node)
        call_node.block.is_a?(Prism::BlockNode) ||
          call_node.block.is_a?(Prism::BlockArgumentNode)
      end

      def with_context(variable, value)
        previous = instance_variable_get(variable)
        instance_variable_set(variable, value)
        yield
      ensure
        instance_variable_set(variable, previous)
      end
    end
  end
end
