# frozen_string_literal: true

module Hone
  class SuggestionGenerator
    TRANSFORMS = {
      positive_predicate: ->(code) { code.gsub(".positive?", " > 0") },
      negative_predicate: ->(code) { code.gsub(".negative?", " < 0") },
      zero_predicate: ->(code) { code.gsub(".zero?", " == 0") },
      map_select_chain: ->(code) { code.gsub(/\.map\s*[({].*?[)}]\s*\.select/, ".filter_map") },
      kernel_loop: ->(code) { code.gsub(/\bloop\s*(?:do|\{)/, "while true do") },
      chars_map_ord: ->(code) { code.gsub(/\.chars\.map\s*\(&:ord\)/, ".bytes") },
      dynamic_ivar: ->(code) { code },
      dynamic_ivar_get: ->(code) { code },
      lazy_ivar: ->(code) { code.gsub(/defined\?\(@\w+\)\s*\?\s*@(\w+)\s*:/, '@\1 ||=') },
      slice_with_length: ->(code) { code.gsub(/\[(\d+),\s*\w+\.(?:length|size)\]/, '[\1..]') }
    }.freeze

    def self.generate(pattern_id, code)
      transform = TRANSFORMS[pattern_id]
      transform ? transform.call(code) : code
    end
  end
end
