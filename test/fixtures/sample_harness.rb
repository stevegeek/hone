# frozen_string_literal: true

$harness_setup_called = false
$harness_exercise_count = 0
$harness_teardown_called = false

setup do
  $harness_setup_called = true
end

exercise iterations: 5 do
  $harness_exercise_count += 1
end

teardown do
  $harness_teardown_called = true
end
