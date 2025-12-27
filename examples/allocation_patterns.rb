# frozen_string_literal: true

# rubocop:disable all
# standardrb:disable all

# Allocation-related patterns that Hone detects
# NOTE: This file intentionally contains anti-patterns for testing

class AllocationPatterns
  # chars.map(&:ord) vs bytes
  def char_codes(str)
    str.chars.map(&:ord)  # Hone: Use `str.bytes` instead
  end

  # map.select vs filter_map
  def transform_and_filter(arr)
    arr.map { |x| x * 2 }.select { |x| x > 10 }  # Hone: Use `filter_map`
  end

  # chars.each vs each_char
  def iterate_chars(str)
    count = 0
    str.chars.each { |c| count += 1 }  # Hone: Use `each_char`
    count
  end

  # map.flatten vs flat_map
  def nested_map(arr)
    arr.map { |x| [x, x * 2] }.flatten  # Hone: Use `flat_map`
  end

  # inject(:+) vs sum
  def total(arr)
    arr.inject(:+)  # Hone: Use `sum`
  end

  # shuffle.first vs sample
  def random_element(arr)
    arr.shuffle.first  # Hone: Use `sample`
  end

  # sort.first vs min
  def smallest(arr)
    arr.sort.first  # Hone: Use `min`
  end

  # reverse.first vs last
  def final_element(arr)
    arr.reverse.first  # Hone: Use `last`
  end

  # String concatenation in loop
  def build_string(parts)
    result = ""
    parts.each do |part|
      result += part  # Hone: Use `<<` or array.join
    end
    result
  end

  # Variable from .chars then indexed
  def char_at(str, i)
    chars = str.chars  # Allocates array
    chars[i]           # Hone: Use `str[i]` directly
  end
end
