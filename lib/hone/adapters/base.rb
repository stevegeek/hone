# frozen_string_literal: true

module Hone
  module Adapters
    class Base
      def initialize(file_path)
        @file_path = file_path
      end

      def findings
        raise NotImplementedError
      end

      private

      def build_finding(line:, message:, pattern_id:, optimization_type: :cpu, code: nil, speedup: nil)
        Finding.new(
          file: @file_path,
          line: line,
          column: 0,
          pattern_id: pattern_id,
          optimization_type: optimization_type,
          source: source_name,
          message: message,
          speedup: speedup,
          code: code
        )
      end

      def source_name
        raise NotImplementedError
      end
    end
  end
end
