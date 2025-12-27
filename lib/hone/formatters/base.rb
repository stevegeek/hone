# frozen_string_literal: true

module Hone
  module Formatters
    class Base
      include Filterable

      def initialize(findings, options = {})
        @findings = findings
        @options = options
        @show_cold = options.fetch(:show_cold, false)
      end

      def format
        raise NotImplementedError, "Subclasses must implement #format"
      end

      private

      def filtered_findings
        filter_cold(@findings, show_cold: @show_cold)
      end
    end
  end
end
