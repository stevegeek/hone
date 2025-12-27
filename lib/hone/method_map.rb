# frozen_string_literal: true

require "prism"

module Hone
  # Maps method definitions to their line ranges for correlating hotspots
  # with specific methods in Ruby source files.
  class MethodMap
    MethodInfo = Data.define(:name, :class_name, :file, :start_line, :end_line) do
      def contains_line?(line)
        (start_line..end_line).cover?(line)
      end

      def qualified_name
        class_name ? "#{class_name}##{name}" : name
      end
    end

    def initialize
      @methods = []
    end

    # Parse a Ruby file and extract all method definitions
    def add_file(path)
      normalized_path = File.expand_path(path)
      result = Prism.parse_file(normalized_path)

      if result.errors.any?
        warn "Parse errors in #{normalized_path}:"
        result.errors.each { |e| warn "  #{e.message}" }
        return self
      end

      extractor = MethodExtractor.new(normalized_path)
      result.value.accept(extractor)
      @methods.concat(extractor.methods)

      self
    end

    # Find the method that contains a given line in a file
    def method_at(file, line)
      normalized_file = File.expand_path(file)

      @methods.find do |method|
        method.file == normalized_file && method.contains_line?(line)
      end
    end

    # Return all methods for a given file
    def methods_in_file(file)
      normalized_file = File.expand_path(file)

      @methods.select do |method|
        method.file == normalized_file
      end
    end

    # Return all registered methods
    def all_methods
      @methods.dup
    end

    # Internal visitor for extracting methods from Prism AST
    class MethodExtractor < Prism::Visitor
      attr_reader :methods

      def initialize(file_path)
        @file_path = file_path
        @methods = []
        @context_stack = []
        super()
      end

      def visit_class_node(node)
        class_name = extract_constant_name(node.constant_path)
        @context_stack.push(class_name)
        super
        @context_stack.pop
      end

      def visit_module_node(node)
        module_name = extract_constant_name(node.constant_path)
        @context_stack.push(module_name)
        super
        @context_stack.pop
      end

      def visit_def_node(node)
        method_name = node.name.to_s
        class_name = @context_stack.any? ? @context_stack.join("::") : nil

        @methods << MethodInfo.new(
          name: method_name,
          class_name: class_name,
          file: @file_path,
          start_line: node.location.start_line,
          end_line: node.location.end_line
        )

        super
      end

      def visit_singleton_method_node(node)
        method_name = "self.#{node.name}"
        class_name = @context_stack.any? ? @context_stack.join("::") : nil

        @methods << MethodInfo.new(
          name: method_name,
          class_name: class_name,
          file: @file_path,
          start_line: node.location.start_line,
          end_line: node.location.end_line
        )

        super
      end

      private

      def extract_constant_name(node)
        case node
        when Prism::ConstantReadNode
          node.name.to_s
        when Prism::ConstantPathNode
          parts = []
          current = node
          while current.is_a?(Prism::ConstantPathNode)
            parts.unshift(current.name.to_s)
            current = current.parent
          end
          parts.unshift(current.name.to_s) if current.is_a?(Prism::ConstantReadNode)
          parts.join("::")
        else
          node.to_s
        end
      end
    end
  end
end
