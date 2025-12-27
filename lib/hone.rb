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
require_relative "hone/patterns/hash_each_key"
require_relative "hone/patterns/shuffle_first"
require_relative "hone/patterns/sort_first"
require_relative "hone/patterns/count_vs_size"
require_relative "hone/patterns/map_flatten"
require_relative "hone/patterns/inject_sum"
require_relative "hone/patterns/gsub_to_tr"
require_relative "hone/patterns/hash_keys_include"
require_relative "hone/patterns/select_count"
require_relative "hone/patterns/range_include"
require_relative "hone/patterns/select_first"
require_relative "hone/patterns/string_chars_each"
require_relative "hone/patterns/redundant_string_chars"
require_relative "hone/patterns/parallel_assignment"
require_relative "hone/patterns/string_shovel"
require_relative "hone/patterns/yield_vs_block"
require_relative "hone/patterns/sort_by_first"
require_relative "hone/patterns/sort_last"
require_relative "hone/patterns/sort_by_last"
require_relative "hone/patterns/hash_values_include"
require_relative "hone/patterns/hash_each_value"
require_relative "hone/patterns/hash_merge_bang"
require_relative "hone/patterns/string_delete_prefix"
require_relative "hone/patterns/string_delete_suffix"
require_relative "hone/patterns/string_casecmp"
require_relative "hone/patterns/string_start_with"
require_relative "hone/patterns/string_end_with"
require_relative "hone/patterns/string_empty"
require_relative "hone/patterns/map_compact"
require_relative "hone/patterns/select_map"
require_relative "hone/patterns/reverse_first"
require_relative "hone/patterns/times_map"
require_relative "hone/patterns/each_with_object"
require_relative "hone/patterns/block_to_proc"
require_relative "hone/patterns/regexp_match"
require_relative "hone/patterns/constant_regexp"
require_relative "hone/patterns/sort_reverse"
require_relative "hone/patterns/array_compact"
require_relative "hone/patterns/bsearch_vs_find"
require_relative "hone/patterns/divmod"
require_relative "hone/patterns/flatten_once"
require_relative "hone/patterns/uniq_by"
require_relative "hone/patterns/array_include_set"
require_relative "hone/patterns/taint_tracking_base"
require_relative "hone/patterns/chars_to_variable"
require_relative "hone/patterns/chars_to_variable_tainted"

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

# Harness
require_relative "hone/harness"
require_relative "hone/harness_runner"
require_relative "hone/harness_generator"
require_relative "hone/config"

module Hone
  class Error < StandardError; end
end
