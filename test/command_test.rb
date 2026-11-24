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

  def test_a_command_ignoring_term_is_killed_without_noise
    result = nil
    _, errors = capture_io { result = M2Load::Command.run(["/bin/sh", "-c", "trap '' TERM; /bin/sleep 30"], 0.2) }
    assert result.timed_out
    assert_equal "", errors
  end

  def test_timeout_kills_the_whole_process_group
    Dir.mktmpdir do |dir|
      pid_file = File.join(dir, "pid")
      M2Load::Command.run(["/bin/sh", "-c", "/bin/sleep 30 & echo $! > #{pid_file}; wait"], 0.3)
      grandchild = Integer(File.read(pid_file))
      assert gone?(grandchild), "grandchild #{grandchild} survived"
    end
  end

  private

  def gone?(pid)
    20.times do
      Process.kill(0, pid)
      sleep 0.05
    end
    false
  rescue Errno::ESRCH
    true
  end
end
