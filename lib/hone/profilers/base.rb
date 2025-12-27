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
        name, file = extract_search_criteria(method_info)

        @frames.find do |frame|
          matches_method?(frame, name, file)
        end
      end

      def extract_search_criteria(method_info)
        case method_info
        when String
          [method_info, nil]
        when Hash
          extract_from_hash(method_info)
        else
          extract_from_object(method_info)
        end
      end

      # Extracts name and file from a Hash with symbol or string keys.
      #
      # @param hash [Hash] Hash containing :name/:file or "name"/"file" keys
      # @return [Array<String, String>] [name, file] tuple
      #
      def extract_from_hash(hash)
        [hash[:name] || hash["name"], hash[:file] || hash["file"]]
      end

      # Extracts name and file from objects with method accessors (like MethodInfo).
      #
      # @param obj [Object] Object responding to :qualified_name/:name and optionally :file
      # @return [Array<String, String>] [name, file] tuple
      #
      def extract_from_object(obj)
        if obj.respond_to?(:qualified_name)
          [obj.qualified_name, obj.file]
        elsif obj.respond_to?(:name)
          [obj.name, obj.respond_to?(:file) ? obj.file : nil]
        else
          [obj.to_s, nil]
        end
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
