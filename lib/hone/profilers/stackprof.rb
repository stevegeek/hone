# frozen_string_literal: true

module Hone
  module Profilers
    class StackProf < Base
      include MethodMatching

      def initialize(profile_path)
        super

        @total_samples = @data["samples"] || calculate_total_samples
        parse_frames
      end

      # Returns CPU percentage for a method (0.0-100.0)
      # method_info can be a Hash with :name and/or :file keys, or a String method name
      def cpu_percent_for(method_info)
        frame = find_matching_frame(method_info)
        return nil unless frame

        frame[:cpu_percent]
      end

      # Returns array of HotspotInfo for frames above threshold
      def hotspots(threshold: 1.0)
        @frames
          .select { |frame| frame[:cpu_percent] >= threshold }
          .sort_by { |frame| -frame[:cpu_percent] }
          .map { |frame| build_hotspot_info(frame) }
      end

      private

      def parse_frames
        @frames = []

        if @data["frames"]
          # Raw StackProf JSON format: frames is a hash with address keys
          @data["frames"].each_value do |frame_data|
            @frames << parse_frame_data(frame_data)
          end
        elsif @data["methods"]
          # Pre-processed Hone format: methods is an array
          @data["methods"].each do |method_data|
            @frames << parse_method_data(method_data)
          end
        end

        @frames.sort_by! { |f| -f[:cpu_percent] }
      end

      def parse_frame_data(frame_data)
        samples = frame_data["samples"] || 0
        cpu_percent = calculate_percent(samples)

        {
          name: frame_data["name"],
          file: frame_data["file"],
          line: frame_data["line"],
          samples: samples,
          total_samples: frame_data["total_samples"] || 0,
          cpu_percent: cpu_percent
        }
      end

      def parse_method_data(method_data)
        samples = method_data["samples"] || 0
        # Use pre-calculated percent if available, otherwise calculate
        cpu_percent = method_data["percent"] || calculate_percent(samples)

        {
          name: method_data["name"],
          file: method_data["file"],
          line: method_data["line"],
          samples: samples,
          total_samples: method_data["total_samples"] || 0,
          cpu_percent: cpu_percent.to_f
        }
      end

      def calculate_total_samples
        if @data["frames"]
          @data["frames"].values.sum { |f| f["samples"] || 0 }
        elsif @data["methods"]
          @data["methods"].sum { |m| m["samples"] || 0 }
        else
          1 # Avoid division by zero
        end
      end

      def calculate_percent(samples)
        return 0.0 if @total_samples.zero?

        (samples.to_f / @total_samples * 100).round(2)
      end
    end
  end
end
