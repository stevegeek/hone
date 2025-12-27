# frozen_string_literal: true

module Hone
  # Correlates static analysis findings with runtime profiler data to prioritize
  # optimizations based on actual CPU and allocation impact.
  #
  # Hone's core value proposition is that not all optimization opportunities are
  # equal. A pattern detected in a hot method that consumes 10% of CPU time is
  # far more valuable to fix than the same pattern in cold initialization code.
  #
  # The Correlator bridges static and dynamic analysis by:
  # 1. Looking up which method contains each finding
  # 2. Retrieving CPU percentage from profiler data (if available)
  # 3. Retrieving allocation percentage from memory profile (if available)
  # 4. Assigning priority based on thresholds and optimization type
  # 5. Sorting findings by impact (hottest first)
  #
  # @example Basic usage with profile data
  #   method_map = Hone::MethodMap.new.add_file("app.rb")
  #   cpu_profile = Hone::ProfileData.load("cpu_profile.json")
  #   memory_profile = Hone::MemoryProfile.load("memory_profile.json")
  #   correlator = Hone::Correlator.new(method_map:, cpu_profile:, memory_profile:)
  #
  #   scanner = Hone::Scanner.new
  #   findings = scanner.scan_file("app.rb")
  #
  #   prioritized = correlator.correlate(findings)
  #   prioritized.each do |finding|
  #     puts "#{finding.priority}: #{finding.message} (#{finding.cpu_percent}% CPU, #{finding.alloc_percent}% alloc)"
  #   end
  #
  # @example Usage without profile data (static-only mode)
  #   method_map = Hone::MethodMap.new.add_file("app.rb")
  #   correlator = Hone::Correlator.new(method_map:)
  #
  #   findings = scanner.scan_file("app.rb")
  #   enriched = correlator.correlate(findings)
  #   # All findings will have priority: :unknown
  #
  # @see MethodMap For building the method-to-line mapping
  # @see Scanner For generating findings from static analysis
  #
  class Correlator
    # Threshold for hot methods: >5% of CPU/allocation time
    # These represent critical optimization targets
    HOT_THRESHOLD = 5.0

    # Threshold for warm methods: 1-5% of CPU/allocation time
    # These are worth optimizing but less urgent than hot
    WARM_THRESHOLD = 1.0

    # Multi-dimension priority levels assigned to findings based on CPU/allocation usage
    # @return [Array<Symbol>] Valid priority values
    PRIORITIES = %i[hot_cpu hot_alloc jit_unfriendly warm cold unknown].freeze

    # Creates a new Correlator with method mapping and optional profiler data.
    #
    # @param method_map [MethodMap] Mapping of source locations to method definitions
    # @param cpu_profile [#cpu_percent_for, nil] CPU profiler data responding to
    #   #cpu_percent_for(method) returning Float or nil. When nil, CPU-based
    #   priorities cannot be calculated.
    # @param memory_profile [#alloc_percent_for, nil] Memory profiler data responding to
    #   #alloc_percent_for(method) returning Float or nil. When nil, allocation-based
    #   priorities cannot be calculated.
    # @param profile_data [#cpu_percent_for, nil] DEPRECATED: Use cpu_profile instead.
    #   Kept for backward compatibility.
    # @param hot_threshold [Float] Threshold for hot methods (default: HOT_THRESHOLD).
    #   Methods with CPU or allocation usage above this are marked :hot_cpu or :hot_alloc.
    # @param warm_threshold [Float] Threshold for warm methods (default: WARM_THRESHOLD).
    #   Methods with usage between warm and hot thresholds are marked :warm.
    #
    def initialize(method_map:, cpu_profile: nil, memory_profile: nil, profile_data: nil,
      hot_threshold: HOT_THRESHOLD, warm_threshold: WARM_THRESHOLD)
      @method_map = method_map
      # Support backward compatibility: profile_data is treated as cpu_profile
      @cpu_profile = cpu_profile || profile_data
      @memory_profile = memory_profile
      @hot_threshold = hot_threshold
      @warm_threshold = warm_threshold
    end

    # @return [Float] Threshold for hot methods
    attr_reader :hot_threshold

    # @return [Float] Threshold for warm methods
    attr_reader :warm_threshold

    # Correlates findings with runtime profile data.
    #
    # For each finding, this method:
    # 1. Looks up the containing method using the MethodMap
    # 2. Queries the profiler for CPU percentage (if cpu_profile present)
    # 3. Queries the profiler for allocation percentage (if memory_profile present)
    # 4. Calculates priority based on thresholds and optimization type
    # 5. Returns enriched findings sorted by impact (descending)
    #
    # @param findings [Array<Finding>] Raw findings from Scanner
    # @return [Array<Finding>] Enriched findings with method_name, cpu_percent,
    #   alloc_percent, and priority populated, sorted by max impact descending
    #
    # @example
    #   raw_findings = scanner.scan_file("hot_code.rb")
    #   prioritized = correlator.correlate(raw_findings)
    #
    #   # Process hot CPU findings first
    #   prioritized.select { |f| f.priority == :hot_cpu }.each do |finding|
    #     puts "URGENT: #{finding.message}"
    #   end
    #
    def correlate(findings)
      enriched = findings.map do |finding|
        enrich_finding(finding)
      end

      sort_by_impact(enriched)
    end

    # Returns findings filtered by priority level.
    #
    # @param findings [Array<Finding>] Correlated findings
    # @param priority [Symbol] One of :hot, :warm, :cold, :unknown
    # @return [Array<Finding>] Findings matching the given priority
    #
    def self.filter_by_priority(findings, priority)
      findings.select { |f| f.priority == priority }
    end

    # Groups findings by priority for reporting.
    #
    # @param findings [Array<Finding>] Correlated findings
    # @return [Hash<Symbol, Array<Finding>>] Findings grouped by priority
    #
    def self.group_by_priority(findings)
      findings.group_by(&:priority)
    end

    # Returns summary statistics for correlated findings.
    #
    # @param findings [Array<Finding>] Correlated findings
    # @return [Hash] Statistics including counts by priority
    #
    def self.summary(findings)
      by_priority = group_by_priority(findings)

      {
        total: findings.size,
        hot_cpu: by_priority[:hot_cpu]&.size || 0,
        hot_alloc: by_priority[:hot_alloc]&.size || 0,
        jit_unfriendly: by_priority[:jit_unfriendly]&.size || 0,
        warm: by_priority[:warm]&.size || 0,
        cold: by_priority[:cold]&.size || 0,
        unknown: by_priority[:unknown]&.size || 0,
        max_cpu_percent: findings.filter_map(&:cpu_percent).max || 0.0,
        total_cpu_percent: findings.filter_map(&:cpu_percent).sum,
        max_alloc_percent: findings.filter_map(&:alloc_percent).max || 0.0,
        total_alloc_percent: findings.filter_map(&:alloc_percent).sum
      }
    end

    private

    # Enriches a single finding with method and profiling information.
    #
    # @param finding [Finding] Raw finding from scanner
    # @return [Finding] New finding with method_name, cpu_percent, alloc_percent, priority set
    #
    def enrich_finding(finding)
      method = @method_map.method_at(finding.file, finding.line)
      cpu_percent = lookup_cpu_percent(method)
      alloc_percent = lookup_alloc_percent(method)
      priority = calculate_priority(finding.optimization_type, cpu_percent, alloc_percent)

      finding.with(
        method_name: method&.qualified_name,
        cpu_percent: cpu_percent,
        alloc_percent: alloc_percent,
        priority: priority
      )
    end

    # Looks up CPU percentage for a method from profile data.
    #
    # @param method [MethodMap::MethodInfo, nil] Method to look up
    # @return [Float, nil] CPU percentage or nil if unavailable
    #
    def lookup_cpu_percent(method)
      return nil unless method && @cpu_profile

      @cpu_profile.cpu_percent_for(method)
    end

    # Looks up allocation percentage for a method from memory profile data.
    #
    # @param method [MethodMap::MethodInfo, nil] Method to look up
    # @return [Float, nil] Allocation percentage or nil if unavailable
    #
    def lookup_alloc_percent(method)
      return nil unless method && @memory_profile

      @memory_profile.alloc_percent_for(method)
    end

    # Calculates priority based on optimization type and CPU/allocation thresholds.
    #
    # Priority levels:
    # - :jit_unfriendly - JIT-related patterns (highest priority regardless of metrics)
    # - :hot_cpu   - More than 5% CPU (critical path, high-value optimization)
    # - :hot_alloc - More than 5% allocations (memory-intensive, high-value optimization)
    # - :warm      - 1-5% CPU or allocation (noticeable impact, worth fixing)
    # - :cold      - Less than 1% CPU and allocation (low priority, fix when convenient)
    # - :unknown   - No profile data available
    #
    # @param optimization_type [Symbol, nil] Type of optimization (e.g., :jit)
    # @param cpu_percent [Float, nil] CPU percentage for the method
    # @param alloc_percent [Float, nil] Allocation percentage for the method
    # @return [Symbol] One of :jit_unfriendly, :hot_cpu, :hot_alloc, :warm, :cold, :unknown
    #
    def calculate_priority(optimization_type, cpu_percent, alloc_percent)
      # JIT patterns get special priority regardless of CPU/alloc
      return :jit_unfriendly if optimization_type == :jit

      # Check for hot CPU first (most important)
      return :hot_cpu if cpu_percent && cpu_percent >= @hot_threshold

      # Check for hot allocation
      return :hot_alloc if alloc_percent && alloc_percent >= @hot_threshold

      # Check for warm (either dimension)
      max_percent = [cpu_percent || 0, alloc_percent || 0].max
      return :warm if max_percent >= @warm_threshold

      # Cold if we have any data
      return :cold if cpu_percent || alloc_percent

      # Unknown if no profile data
      :unknown
    end

    # Sorts findings by impact (max of CPU or allocation), hottest first.
    #
    # Findings with nil cpu_percent and alloc_percent are sorted last (treated as 0).
    #
    # @param findings [Array<Finding>] Enriched findings
    # @return [Array<Finding>] Sorted findings (descending by max impact)
    #
    def sort_by_impact(findings)
      findings.sort_by { |f| -[f.cpu_percent || 0, f.alloc_percent || 0].max }
    end
  end
end
