require_relative "test_helper"

class CommandTest < Minitest::Test
  def test_returns_output_error_and_status
    result = M2Load::Command.run(["/bin/sh", "-c", "echo out; echo err >&2; exit 3"], 5)
    refute result.success
    assert_equal "out\n", result.stdout
    assert_equal "err\n", result.stderr
    refute result.timed_out
  end

  def test_success
    assert M2Load::Command.run(["/usr/bin/true"], 5).success
  end

  def test_stops_a_command_that_outlives_the_timeout
    started = Time.now
    result = M2Load::Command.run(["/bin/sleep", "5"], 0.2)
    assert result.timed_out
    refute result.success
    assert_operator Time.now - started, :<, 3
  end

  def test_missing_program_is_a_failure
    result = M2Load::Command.run(["/nonexistent/program"], 5)
    refute result.success
    refute_empty result.stderr
  end
end
