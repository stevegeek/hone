# frozen_string_literal: true

require_relative "hone/version"
require_relative "hone/exit_codes"
require_relative "hone/finding"
require_relative "hone/method_map"

# Patterns
require_relative "hone/patterns/base"
require_relative "hone/patterns/positive_predicate"
require_relative "hone/patterns/kernel_loop"
require_relative "hone/patterns/slice_with_length"
require_relative "hone/patterns/chars_map_ord"
require_relative "hone/patterns/map_select_chain"
require_relative "hone/patterns/dynamic_ivar"
require_relative "hone/patterns/dynamic_ivar_get"
require_relative "hone/patterns/lazy_ivar"
require_relative "hone/patterns/each_with_index"
require_relative "hone/patterns/string_concat_in_loop"
require_relative "hone/patterns/reverse_each"
require_relative "hone/patterns/count_vs_size"

require_relative "hone/scanner"

# Adapters
require_relative "hone/adapters/base"
require_relative "hone/adapters/fasterer"
require_relative "hone/adapters/rubocop_performance"

# Profilers
require_relative "hone/profilers/base"
require_relative "hone/profilers/stackprof"
require_relative "hone/profilers/vernier"
require_relative "hone/profilers/memory_profiler"
require_relative "hone/profilers/factory"

# Correlation
require_relative "hone/correlator"
require_relative "hone/finding_filter"

# Reporting
require_relative "hone/suggestion_generator"
require_relative "hone/formatters/filterable"
require_relative "hone/formatters/base"
require_relative "hone/reporter"
require_relative "hone/formatters/json"
require_relative "hone/formatters/github"
require_relative "hone/formatters/sarif"
require_relative "hone/formatters/junit"
require_relative "hone/formatters/tsv"

# Orchestration
require_relative "hone/analyzer"

module Hone
  class Error < StandardError; end
end
