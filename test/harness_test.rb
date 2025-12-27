# frozen_string_literal: true

require "test_helper"

class HarnessTest < Minitest::Test
  def setup
    @fixture_path = File.expand_path("fixtures/sample_harness.rb", __dir__)
    # Reset globals
    $harness_setup_called = false
    $harness_exercise_count = 0
    $harness_teardown_called = false
  end

  def test_load_harness
    harness = Hone::Harness.load(@fixture_path)

    assert harness.valid?
    assert_equal 5, harness.iterations
  end

  def test_run_setup
    harness = Hone::Harness.load(@fixture_path)
    harness.run_setup

    assert $harness_setup_called
  end

  def test_run_exercise
    harness = Hone::Harness.load(@fixture_path)
    harness.run_exercise

    assert_equal 1, $harness_exercise_count
  end

  def test_run_teardown
    harness = Hone::Harness.load(@fixture_path)
    harness.run_teardown

    assert $harness_teardown_called
  end

  def test_load_missing_file
    assert_raises(Hone::Error) do
      Hone::Harness.load("nonexistent.rb")
    end
  end

  def test_invalid_harness_without_exercise
    harness = Hone::Harness.new
    refute harness.valid?
  end
end
