# frozen_string_literal: true

require "json"

module Hone
  module Profilers
    # Shared data structure for hotspot information across all profilers
    HotspotInfo = Data.define(:name, :file, :line, :cpu_percent, :samples)

    # Shared method matching logic for profiler implementations.
    # Provides utilities to find and match methods/frames by name and file.
    module MethodMatching
      private

      def find_matching_frame(method_info)
        name, file, line, end_line = extract_search_criteria(method_info)

        # First try to match by line range (for allocation profilers)
        if line && file
          match = @frames.find do |frame|
            next unless frame[:file] && frame[:line]
            next unless file_matches?(frame[:file], file)

            frame_line = frame[:line].to_i
            if end_line
              # Method has a range, check if frame line is within it
              frame_line >= line && frame_line <= end_line
            else
              # Exact line match
              frame_line == line
            end
          end
          return match if match
        end

        # Fall back to name-based matching
        @frames.find do |frame|
          matches_method?(frame, name, file)
        end
      end

      def extract_search_criteria(method_info)
        case method_info
        when String
          [method_info, nil, nil, nil]
        when Hash
          extract_from_hash(method_info)
        else
          extract_from_object(method_info)
        end
      end

      # Extracts name, file, line, and end_line from a Hash with symbol or string keys.
      #
      # @param hash [Hash] Hash containing :name/:file/:line/:end_line keys
      # @return [Array] [name, file, line, end_line] tuple
      #
      def extract_from_hash(hash)
        [
          hash[:name] || hash["name"],
          hash[:file] || hash["file"],
          hash[:line] || hash["line"],
          hash[:end_line] || hash["end_line"]
        ]
      end

      # Extracts name, file, line, end_line from objects with method accessors (like MethodInfo).
      #
      # @param obj [Object] Object responding to :qualified_name/:name and optionally :file/:line/:end_line
      # @return [Array] [name, file, line, end_line] tuple
      #
      def extract_from_object(obj)
        name = if obj.respond_to?(:qualified_name)
          obj.qualified_name
        elsif obj.respond_to?(:name)
          obj.name
        else
          obj.to_s
        end

        file = obj.respond_to?(:file) ? obj.file : nil
        # Support both :line and :start_line for compatibility
        line = if obj.respond_to?(:start_line)
          obj.start_line
        elsif obj.respond_to?(:line)
          obj.line
        end
        end_line = obj.respond_to?(:end_line) ? obj.end_line : nil

        [name, file, line, end_line]
      end

      def matches_method?(frame, name, file)
        return false unless name

        name_matches = method_name_matches?(frame[:name], name)
        return name_matches unless file && name_matches

        # If file is provided, also check file match
        file_matches?(frame[:file], file)
      end

      def method_name_matches?(frame_name, search_name)
        return false unless frame_name

        # Exact match
        return true if frame_name == search_name

        # Match without class prefix (e.g., "method_name" matches "ClassName#method_name")
        return true if frame_name.end_with?("##{search_name}")

        # Match with class prefix when searching for just method name
        frame_method = frame_name.split("#").last
        frame_method == search_name
      end

      def file_matches?(frame_file, search_file)
        return false unless frame_file && search_file

        # Exact match or path suffix match
        frame_file == search_file || frame_file.end_with?(search_file) || search_file.end_with?(File.basename(frame_file))
      end

      def build_hotspot_info(frame)
        HotspotInfo.new(
          name: frame[:name],
          file: frame[:file],
          line: frame[:line],
          cpu_percent: frame[:cpu_percent],
          samples: frame[:samples]
        )
      end
    end

    class Base
      def initialize(profile_path)
        @profile_path = profile_path
        @data = load_profile(profile_path)
      end

      # Returns CPU percentage for a method (0.0-100.0)
      def cpu_percent_for(method_info)
        raise NotImplementedError
      end

      # Returns all hotspots above threshold
      def hotspots(threshold: 1.0)
        raise NotImplementedError
      end

      private

      def load_profile(path)
        raise Hone::Error, "Profile file not found: #{path}" unless File.exist?(path)

        JSON.parse(File.read(path))
      rescue JSON::ParserError => e
        raise Hone::Error, "Invalid JSON in profile file #{path}: #{e.message}"
      end
    end
  end
end
