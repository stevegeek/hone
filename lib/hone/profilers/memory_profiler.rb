# frozen_string_literal: true

module Hone
  module Profilers
    class MemoryProfiler < Base
      include MethodMatching

      def initialize(profile_path)
        super

        parse_allocations
      end

      # Returns CPU percentage for a method (0.0-100.0)
      # Always returns nil for MemoryProfiler since it tracks allocations, not CPU
      def cpu_percent_for(_method_info)
        nil
      end

      # Returns allocation percentage for a method (0.0-100.0)
      # method_info can be a Hash with :name and/or :file keys, or a String method name
      def alloc_percent_for(method_info)
        frame = find_matching_frame(method_info)
        return nil unless frame

        frame[:alloc_percent]
      end

      # Returns array of HotspotInfo for frames above threshold
      # For MemoryProfiler, threshold applies to allocation percentage
      def hotspots(threshold: 1.0)
        @frames
          .select { |frame| frame[:alloc_percent] >= threshold }
          .sort_by { |frame| -frame[:alloc_percent] }
          .map { |frame| build_hotspot_info(frame) }
      end

      private

      def parse_allocations
        @frames = []
        @total_allocations = 0

        # MemoryProfiler can output in various formats
        # Common structures include allocated_memory_by_location, allocated_objects_by_location
        allocation_data = extract_allocation_data

        # Calculate total allocations for percentage
        @total_allocations = allocation_data.values.sum { |info| info[:count] }
        @total_allocations = 1 if @total_allocations.zero?

        # Build frames array from allocation data
        allocation_data.each do |location, info|
          alloc_percent = (info[:count].to_f / @total_allocations * 100).round(2)

          @frames << {
            name: info[:name],
            file: info[:file],
            line: info[:line],
            samples: info[:count],
            alloc_percent: alloc_percent,
            cpu_percent: nil,
            memory_allocated: info[:memory_allocated]
          }
        end

        @frames.sort_by! { |f| -f[:alloc_percent] }
      end

      def extract_allocation_data
        allocation_data = {}

        # Try different MemoryProfiler output formats
        if @data["allocated_objects_by_location"]
          parse_by_location(@data["allocated_objects_by_location"], allocation_data)
        elsif @data["allocated_memory_by_location"]
          parse_by_location(@data["allocated_memory_by_location"], allocation_data, memory: true)
        elsif @data["allocations"]
          parse_allocations_array(@data["allocations"], allocation_data)
        elsif @data["allocated_objects_by_gem"]
          # Fallback to gem-level data if location data not available
          parse_by_gem(@data["allocated_objects_by_gem"], allocation_data)
        else
          # Try to parse as raw location-based data
          parse_raw_data(allocation_data)
        end

        allocation_data
      end

      def parse_by_location(location_data, allocation_data, memory: false)
        location_data.each do |entry|
          location = entry["location"] || entry["data"]
          count = entry["count"] || entry["value"] || 1
          memory_allocated = entry["memory"] || entry["memsize"] || 0

          file, line, name = parse_location(location)
          key = "#{file}:#{line}"

          if allocation_data[key]
            allocation_data[key][:count] += count
            allocation_data[key][:memory_allocated] += memory_allocated
          else
            allocation_data[key] = {
              name: name,
              file: file,
              line: line,
              count: count,
              memory_allocated: memory_allocated
            }
          end
        end
      end

      def parse_allocations_array(allocations, allocation_data)
        allocations.each do |entry|
          file = entry["file"] || entry["sourcefile"]
          line = entry["line"] || entry["sourceline"]
          name = entry["name"] || entry["class_name"] || entry["method"] || "#{file}:#{line}"
          count = entry["count"] || entry["allocations"] || 1
          memory_allocated = entry["memory"] || entry["memsize"] || entry["size"] || 0

          key = "#{file}:#{line}"

          if allocation_data[key]
            allocation_data[key][:count] += count
            allocation_data[key][:memory_allocated] += memory_allocated
          else
            allocation_data[key] = {
              name: name,
              file: file,
              line: line.to_i,
              count: count,
              memory_allocated: memory_allocated
            }
          end
        end
      end

      def parse_by_gem(gem_data, allocation_data)
        gem_data.each do |entry|
          gem_name = entry["gem"] || entry["data"] || "unknown"
          count = entry["count"] || entry["value"] || 1

          allocation_data[gem_name] = {
            name: gem_name,
            file: nil,
            line: nil,
            count: count,
            memory_allocated: 0
          }
        end
      end

      def parse_raw_data(allocation_data)
        # Handle case where data is a simple hash of location => count
        @data.each do |key, value|
          next unless value.is_a?(Integer) || value.is_a?(Hash)

          if value.is_a?(Integer)
            file, line, name = parse_location(key)
            allocation_data[key] = {
              name: name,
              file: file,
              line: line,
              count: value,
              memory_allocated: 0
            }
          elsif value.is_a?(Hash) && (value["count"] || value["allocations"])
            file, line, name = parse_location(key)
            allocation_data[key] = {
              name: name,
              file: file,
              line: line,
              count: value["count"] || value["allocations"] || 1,
              memory_allocated: value["memory"] || value["memsize"] || 0
            }
          end
        end
      end

      def parse_location(location)
        return [nil, nil, location] unless location.is_a?(String)

        # MemoryProfiler location format is typically "file:line" or "file:line:in `method'"
        if location =~ /^(.+):(\d+)(?::in `(.+)')?$/
          file = ::Regexp.last_match(1)
          line = ::Regexp.last_match(2).to_i
          method_name = ::Regexp.last_match(3)

          name = method_name || "#{File.basename(file)}:#{line}"
          [file, line, name]
        else
          [location, nil, location]
        end
      end

      def build_hotspot_info(frame)
        # Note: HotspotInfo.cpu_percent is used for allocation percentage here.
        # The HotspotInfo structure is shared across profiler types and represents
        # "impact percentage" - CPU for StackProf/Vernier, allocations for MemoryProfiler.
        HotspotInfo.new(
          name: frame[:name],
          file: frame[:file],
          line: frame[:line],
          cpu_percent: frame[:alloc_percent],
          samples: frame[:samples]
        )
      end
    end
  end
end
