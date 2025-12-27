# frozen_string_literal: true

module Hone
  module Patterns
    # Base class for patterns that need to track data flow through variables.
    #
    # Provides "taint tracking" - the ability to mark variables with metadata
    # about their origin and propagate that information through assignments.
    #
    # Subclasses should:
    # 1. Override `taint_from_call` to mark variables when assigned from specific calls
    # 2. Override `check_tainted_usage` to detect problematic uses of tainted variables
    #
    # @example Tracking .chars allocations
    #   class CharsTracking < TaintTrackingBase
    #     def taint_from_call(call_node)
    #       return nil unless call_node.name == :chars
    #       { type: :chars, source: call_node.receiver&.slice }
    #     end
    #
    #     def check_tainted_usage(call_node, taint_info)
    #       if call_node.name == :[] && taint_info[:type] == :chars
    #         report_finding(...)
    #       end
    #     end
    #   end
    #
    class TaintTrackingBase < Base
      # Taint info structure
      TaintInfo = Data.define(:type, :source, :source_code, :origin_line, :metadata) do
        def initialize(type:, source: nil, source_code: nil, origin_line: nil, metadata: {})
          super
        end
      end

      def initialize(file_path)
        super
        @taint_scopes = []
      end

      # === Scope Management ===

      def visit_def_node(node)
        with_taint_scope { super }
      end

      def visit_block_node(node)
        with_taint_scope(inherit: true) { super }
      end

      def visit_lambda_node(node)
        with_taint_scope { super }
      end

      def visit_class_node(node)
        with_taint_scope { super }
      end

      def visit_module_node(node)
        with_taint_scope { super }
      end

      # === Variable Tracking ===

      # Track local variable assignments
      def visit_local_variable_write_node(node)
        super
        track_assignment(node.name, node.value, node)
      end

      # Track instance variable assignments
      def visit_instance_variable_write_node(node)
        super
        track_assignment(node.name, node.value, node, scope: :instance)
      end

      # Track multiple assignment (a, b = x, y)
      def visit_multi_write_node(node)
        super
        # For simplicity, clear taints for multi-assigned variables
        node.lefts.each do |target|
          case target
          when Prism::LocalVariableTargetNode
            clear_taint(target.name)
          end
        end
      end

      # Track call nodes for both tainting and usage checking
      def visit_call_node(node)
        super
        check_tainted_call(node)
      end

      # Track variable reads (for propagation detection)
      def visit_local_variable_read_node(node)
        super
        # Subclasses can override to track reads
      end

      protected

      # === Override Points for Subclasses ===

      # Override to define what calls create taints
      # @param call_node [Prism::CallNode] The call being assigned
      # @return [TaintInfo, nil] Taint info if this call should taint, nil otherwise
      def taint_from_call(call_node)
        nil
      end

      # Override to check if a tainted variable is being used problematically
      # @param call_node [Prism::CallNode] The call on a tainted variable
      # @param var_name [Symbol] The variable name
      # @param taint_info [TaintInfo] Information about the taint
      def check_tainted_usage(call_node, var_name, taint_info)
        # Subclasses implement this
      end

      # === Taint Query Methods ===

      # Get taint info for a variable
      def get_taint(var_name, scope: :local)
        case scope
        when :local
          current_taint_scope[:locals][var_name]
        when :instance
          current_taint_scope[:instance][var_name]
        end
      end

      # Check if a variable is tainted
      def tainted?(var_name, scope: :local)
        !get_taint(var_name, scope: scope).nil?
      end

      # Set taint for a variable
      def set_taint(var_name, taint_info, scope: :local)
        case scope
        when :local
          current_taint_scope[:locals][var_name] = taint_info
        when :instance
          current_taint_scope[:instance][var_name] = taint_info
        end
      end

      # Clear taint for a variable (e.g., on reassignment)
      def clear_taint(var_name, scope: :local)
        case scope
        when :local
          current_taint_scope[:locals].delete(var_name)
        when :instance
          current_taint_scope[:instance].delete(var_name)
        end
      end

      # Get all tainted variables in current scope
      def all_taints(scope: :local)
        case scope
        when :local
          current_taint_scope[:locals].dup
        when :instance
          current_taint_scope[:instance].dup
        end
      end

      private

      def with_taint_scope(inherit: false)
        new_scope = {
          locals: {},
          instance: (inherit && @taint_scopes.any?) ? current_taint_scope[:instance].dup : {}
        }
        @taint_scopes.push(new_scope)
        yield
      ensure
        @taint_scopes.pop
      end

      def current_taint_scope
        @taint_scopes.last || {locals: {}, instance: {}}
      end

      def track_assignment(var_name, value_node, assignment_node, scope: :local)
        # If assigned from a call, check if it should be tainted
        if value_node.is_a?(Prism::CallNode)
          taint_info = taint_from_call(value_node)
          if taint_info
            # Ensure it's a TaintInfo
            taint_info = if taint_info.is_a?(TaintInfo)
              taint_info
            else
              TaintInfo.new(**taint_info)
            end
            set_taint(var_name, taint_info, scope: scope)
            return
          end
        end

        # If assigned from another variable, propagate taint
        if value_node.is_a?(Prism::LocalVariableReadNode)
          source_taint = get_taint(value_node.name)
          if source_taint
            set_taint(var_name, source_taint, scope: scope)
            return
          end
        end

        # Otherwise, clear any existing taint (variable reassigned to non-tainted value)
        clear_taint(var_name, scope: scope)
      end

      def check_tainted_call(node)
        # Check if this is a call on a tainted local variable
        if node.receiver.is_a?(Prism::LocalVariableReadNode)
          var_name = node.receiver.name
          taint_info = get_taint(var_name)
          check_tainted_usage(node, var_name, taint_info) if taint_info
        end

        # Check if this is a call on a tainted instance variable
        if node.receiver.is_a?(Prism::InstanceVariableReadNode)
          var_name = node.receiver.name
          taint_info = get_taint(var_name, scope: :instance)
          check_tainted_usage(node, var_name, taint_info) if taint_info
        end
      end
    end
  end
end
