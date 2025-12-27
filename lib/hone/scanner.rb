# frozen_string_literal: true

require "prism"

module Hone
  # Scans Ruby files for optimization patterns using Prism AST analysis.
  # Coordinates multiple pattern matchers and collects their findings.
  class Scanner
    # Default glob pattern for finding Ruby files
    DEFAULT_RUBY_GLOB = "**/*.rb"

    def initialize(patterns: Patterns.registered)
      @patterns = patterns
    end

    # Scan a single file with all patterns
    # Returns an array of findings from all pattern matchers
    def scan_file(path)
      result = Prism.parse_file(path)

      if result.errors.any?
        warn "Parse errors in #{path}:"
        result.errors.each { |e| warn "  #{e.message}" }
        return []
      end

      @patterns.flat_map do |pattern_class|
        matcher = pattern_class.new(path)
        result.value.accept(matcher)
        matcher.findings
      end
    end

    # Scan all Ruby files in a directory
    # Returns an array of findings from all files
    def scan_directory(path, pattern: DEFAULT_RUBY_GLOB)
      files = Dir.glob(File.join(path, pattern))

      files.flat_map do |file|
        scan_file(file)
      end
    end

    # Scan multiple files
    # Returns an array of findings from all files
    def scan_files(paths)
      paths.flat_map { |path| scan_file(path) }
    end

    # Group findings by file
    def self.group_by_file(findings)
      findings.group_by(&:file)
    end

    # Group findings by pattern type
    def self.group_by_pattern(findings)
      findings.group_by(&:pattern_id)
    end

    # Group findings by optimization type (:cpu, :allocation, :jit)
    def self.group_by_optimization_type(findings)
      findings.group_by(&:optimization_type)
    end
  end
end
