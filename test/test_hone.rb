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
end
