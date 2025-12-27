# frozen_string_literal: true

module Hone
  # Represents a single optimization finding from static analysis.
  #
  # @example Creating a finding
  #   finding = Finding.new(
  #     file: "app/models/user.rb",
  #     line: 42,
  #     column: 8,
  #     pattern_id: :positive_predicate,
  #     optimization_type: :cpu,
  #     source: :hone,
  #     message: "Use > 0 instead of .positive?",
  #     speedup: "Minor",
  #     code: "count.positive?"
  #   )
  #
  # @!attribute [r] file
  #   @return [String] Path to the source file
  # @!attribute [r] line
  #   @return [Integer] Line number (1-indexed)
  # @!attribute [r] column
  #   @return [Integer] Column number (0-indexed)
  # @!attribute [r] pattern_id
  #   @return [Symbol] Identifier for the pattern that matched
  # @!attribute [r] optimization_type
  #   @return [Symbol] One of :cpu, :allocation, :jit
  # @!attribute [r] source
  #   @return [Symbol] One of :hone, :fasterer, :rubocop
  # @!attribute [r] message
  #   @return [String] Human-readable description of the optimization
  # @!attribute [r] speedup
  #   @return [String, nil] Expected performance improvement
  # @!attribute [r] code
  #   @return [String] Source code snippet that triggered the finding
  # @!attribute [r] method_name
  #   @return [String, nil] Qualified method name (set by Correlator)
  # @!attribute [r] cpu_percent
  #   @return [Float, nil] CPU percentage from profiler (set by Correlator)
  # @!attribute [r] alloc_percent
  #   @return [Float, nil] Allocation percentage (set by Correlator)
  # @!attribute [r] priority
  #   @return [Symbol, nil] One of :hot, :warm, :cold, :unknown (set by Correlator)
  Finding = Data.define(
    :file,
    :line,
    :column,
    :pattern_id,
    :optimization_type,  # :cpu, :allocation, :jit
    :source,             # :hone, :fasterer, :rubocop
    :message,
    :speedup,            # Optional: "1.5x faster"
    :code,               # Source code snippet
    :method_name,        # Populated by correlator
    :cpu_percent,        # Populated by correlator
    :alloc_percent,      # Populated by correlator (Phase 2)
    :priority            # :hot, :warm, :cold
  ) do
    def initialize(method_name: nil, cpu_percent: nil, alloc_percent: nil, priority: nil, **kwargs)
      super
    end
  end
end
