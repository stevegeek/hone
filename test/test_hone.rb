# frozen_string_literal: true

require "test_helper"

class TestHone < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Hone::VERSION
  end

  def test_scanner_finds_patterns
    scanner = Hone::Scanner.new
    findings = scanner.scan_file("experiments/example_sqids_patterns.rb")

    assert findings.length >= 5, "Expected at least 5 findings"

    pattern_ids = findings.map(&:pattern_id)
    assert_includes pattern_ids, :positive_predicate
    assert_includes pattern_ids, :kernel_loop
    assert_includes pattern_ids, :chars_map_ord
  end

  def test_finding_has_required_attributes
    scanner = Hone::Scanner.new
    findings = scanner.scan_file("experiments/example_sqids_patterns.rb")

    finding = findings.first
    refute_nil finding.file
    refute_nil finding.line
    refute_nil finding.pattern_id
    refute_nil finding.optimization_type
    refute_nil finding.message
  end

  def test_method_map_finds_methods
    mm = Hone::MethodMap.new
    mm.add_file("experiments/example_sqids_patterns.rb")

    method = mm.method_at("experiments/example_sqids_patterns.rb", 24)
    refute_nil method
    assert_equal "decode_chars", method.name
  end

  def test_patterns_have_correct_optimization_types
    scanner = Hone::Scanner.new
    findings = scanner.scan_file("experiments/example_jit_patterns.rb")

    jit_findings = findings.select { |f| f.optimization_type == :jit }
    assert jit_findings.length >= 3, "Expected JIT patterns to be found"
  end

  def test_regexp_match_avoids_dollar_one_false_positives
    scanner = Hone::Scanner.new
    findings = scanner.scan_file("test/fixtures/regexp_match_patterns.rb")

    regexp_findings = findings.select { |f| f.pattern_id == :regexp_match }
    flagged_lines = regexp_findings.map(&:line)

    # Should flag simple cases without $1 usage
    # Line 8: if str =~ /pattern/
    assert_includes flagged_lines, 8, "Should flag simple =~ match (line 8)"
    # Line 15: if /pattern/.match(str)
    assert_includes flagged_lines, 15, "Should flag .match method (line 15)"
    # Line 55: unless str =~ /pattern/
    assert_includes flagged_lines, 55, "Should flag unless without $1 (line 55)"

    # Should NOT flag cases with $1/$2 usage
    # Line 29: if str =~ /(\w+)/ with $1 in body
    refute_includes flagged_lines, 29, "Should NOT flag =~ when $1 is used"
    # Line 36: raise ... if str =~ pattern (modifier if with $1)
    refute_includes flagged_lines, 36, "Should NOT flag =~ when $1 is used in modifier if"
    # Line 41: if str =~ /.../ with $1 and $2 in body
    refute_includes flagged_lines, 41, "Should NOT flag =~ when $2 is used"
    # Line 62: unless str =~ /.../ with $1 in else clause
    refute_includes flagged_lines, 62, "Should NOT flag =~ when $1 is used in else"

    # Should NOT flag assigned match
    # Line 22: if m = str.match(/pattern/)
    refute_includes flagged_lines, 22, "Should NOT flag when match is assigned"

    # Verify total count - should be exactly 3 flagged
    assert_equal 3, regexp_findings.length, "Expected exactly 3 regexp_match findings"
  end
end
