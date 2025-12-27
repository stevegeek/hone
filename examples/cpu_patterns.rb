# frozen_string_literal: true

# rubocop:disable all
# standardrb:disable all

# CPU-related patterns that Hone detects
# NOTE: This file intentionally contains anti-patterns for testing

class CpuPatterns
  # positive? vs > 0
  def check_positive(n)
    n.positive?  # Hone: Use `> 0` instead
  end

  # loop vs while true
  def count_up
    i = 0
    loop do  # Hone: Use `while true` for JIT optimization
      i += 1
      break if i > 100
    end
    i
  end

  # each_with_index vs manual index
  def sum_with_index(arr)
    total = 0
    arr.each_with_index do |val, i|  # Hone: Consider manual indexing in hot loops
      total += val * i
    end
    total
  end

  # Slice with length vs endless range
  def tail(str)
    str[1, str.length]  # Hone: Use `str[1..]` instead
  end

  # gsub single char vs tr
  def replace_spaces(str)
    str.gsub(" ", "_")  # Hone: Use `tr` for single char replacement
  end

  # Regexp in loop
  def match_pattern(strings)
    strings.select do |s|
      s.match?(/\d+/)  # Hone: Extract regexp to constant
    end
  end
end
