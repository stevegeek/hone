# frozen_string_literal: true

require "json"

module Hone
  module Profilers
    class Factory
      DETECTORS = [
        [Vernier, ->(data) { data.key?("threads") }],
        [StackProf, ->(data) { data.key?("frames") || data.key?("methods") }]
      ].freeze

      def self.create(profile_path)
        return nil if profile_path.nil?

        data = JSON.parse(File.read(profile_path))
        profiler_class = detect_profiler(data)

        raise Hone::Error, "Unknown profile format in #{profile_path}" unless profiler_class

        profiler_class.new(profile_path)
      rescue JSON::ParserError => e
        raise Hone::Error, "Invalid profile JSON: #{e.message}"
      end

      def self.detect_profiler(data)
        DETECTORS.find { |_, detector| detector.call(data) }&.first
      end
    end
  end
end
