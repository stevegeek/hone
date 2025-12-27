# frozen_string_literal: true

require "open3"

module Hone
  module Adapters
    class Fasterer < Base
      def findings
        return [] unless fasterer_available?

        parse_output(run_fasterer)
      rescue NotImplementedError => e
        warn "[Hone::Adapters::Fasterer] #{e.message}"
        []
      end

      private

      def source_name
        :fasterer
      end

      def fasterer_available?
        _, _, status = Open3.capture3("which", "fasterer")
        status.success?
      end

      def run_fasterer
        stdout, _stderr, _status = Open3.capture3("fasterer", @file_path)
        stdout
      end

      def parse_output(output)
        raise NotImplementedError, "Fasterer output parsing not yet implemented"
      end
    end
  end
end
