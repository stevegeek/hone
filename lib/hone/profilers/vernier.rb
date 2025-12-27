# frozen_string_literal: true

require "set"

module Hone
  module Profilers
    class Vernier < Base
      include MethodMatching

      def initialize(profile_path)
        super

        parse_profile
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

      def parse_profile
        @frames = []
        @total_samples = 0

        # Vernier uses Firefox Profiler format
        # The structure has: threads[], each with frameTable, funcTable, stackTable, samples
        threads = @data["threads"] || []

        # Aggregate samples across all threads
        frame_samples = Hash.new(0)
        frame_info = {}

        threads.each do |thread|
          parse_thread(thread, frame_samples, frame_info)
        end

        # Calculate total samples for percentage calculation
        @total_samples = frame_samples.values.sum
        @total_samples = 1 if @total_samples.zero?

        # Build frames array
        frame_samples.each do |frame_key, samples|
          info = frame_info[frame_key]
          cpu_percent = (samples.to_f / @total_samples * 100).round(2)

          @frames << {
            name: info[:name],
            file: info[:file],
            line: info[:line],
            samples: samples,
            cpu_percent: cpu_percent
          }
        end

        @frames.sort_by! { |f| -f[:cpu_percent] }
      end

      def parse_thread(thread, frame_samples, frame_info)
        frame_table = thread["frameTable"] || {}
        func_table = thread["funcTable"] || {}
        stack_table = thread["stackTable"] || {}
        samples = thread["samples"] || {}

        # Extract frame data arrays (Firefox Profiler format uses arrays)
        frame_funcs = frame_table["func"] || []
        frame_lines = frame_table["line"] || []

        func_names = func_table["name"] || []
        func_files = func_table["fileName"] || []
        func_lines = func_table["lineNumber"] || []

        # String table for resolving indices to actual strings
        string_table = @data["stringTable"] || thread["stringTable"] || []

        # Stack table: prefix and frame arrays define the stack structure
        stack_prefixes = stack_table["prefix"] || []
        stack_frames = stack_table["frame"] || []

        # Samples: stack indices for each sample
        sample_stacks = samples["stack"] || []

        # Count samples per frame
        sample_stacks.each do |stack_idx|
          next if stack_idx.nil?

          # Walk up the stack and count each frame
          counted_frames = Set.new
          current_stack = stack_idx

          while current_stack && current_stack >= 0 && current_stack < stack_frames.size
            frame_idx = stack_frames[current_stack]

            # Only count each frame once per sample (avoid double-counting in recursion)
            unless counted_frames.include?(frame_idx)
              counted_frames.add(frame_idx)

              # Get function info for this frame
              func_idx = frame_funcs[frame_idx] if frame_idx && frame_idx < frame_funcs.size

              if func_idx && func_idx < func_names.size
                name_idx = func_names[func_idx]
                file_idx = func_files[func_idx] if func_files
                line = func_lines[func_idx] if func_lines

                name = resolve_string(string_table, name_idx)
                file = resolve_string(string_table, file_idx)

                # Use frame line if available, otherwise function line
                frame_line = frame_lines[frame_idx] if frame_idx && frame_idx < frame_lines.size
                line = frame_line if frame_line && frame_line > 0

                frame_key = "#{name}:#{file}:#{line}"
                frame_samples[frame_key] += 1
                frame_info[frame_key] ||= {name: name, file: file, line: line}
              end
            end

            # Move to parent stack
            prefix = stack_prefixes[current_stack]
            current_stack = prefix
          end
        end
      end

      def resolve_string(string_table, index)
        return nil if index.nil?
        return index if index.is_a?(String)

        string_table[index] if index >= 0 && index < string_table.size
      end
    end
  end
end
