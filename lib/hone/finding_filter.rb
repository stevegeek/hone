# frozen_string_literal: true

require "json"
require "set"

module Hone
  class FindingFilter
    def initialize(findings, options = {})
      @findings = findings
      @diff = options[:diff]
      @baseline = options[:baseline]
      @hot_only = options[:hot_only]
      @show_cold = options[:show_cold]
      @profile_path = options[:profile_path]
      @top = options[:top]
    end

    def apply
      filtered = @findings
      filtered = filter_by_diff(filtered) if @diff
      filtered = filter_by_baseline(filtered) if @baseline
      filtered = filter_by_priority(filtered)
      apply_top_limit(filtered)
    end

    private

    def filter_by_diff(findings)
      changed_files = `git diff --name-only #{@diff}`.split("\n").map { |f| File.expand_path(f) }
      findings.select { |f| changed_files.include?(File.expand_path(f.file)) }
    end

    def filter_by_baseline(findings)
      baseline_data = JSON.parse(File.read(@baseline))
      baseline_findings = baseline_data["findings"] || []

      baseline_keys = baseline_findings.map do |bf|
        [bf["file"], bf["line"], bf["pattern_id"]].join(":")
      end.to_set

      findings.reject do |f|
        key = [f.file, f.line, f.pattern_id].join(":")
        baseline_keys.include?(key)
      end
    end

    def filter_by_priority(findings)
      return findings.select { |f| f.priority == :hot } if @hot_only
      return findings.reject { |f| f.priority == :cold } if @profile_path && !@show_cold
      findings
    end

    def apply_top_limit(findings)
      (@top && @top > 0) ? findings.first(@top) : findings
    end
  end
end
