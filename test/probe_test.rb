require_relative "test_helper"

class ProbeTest < Minitest::Test
  include TestSupport

  def probe_answering(result)
    @calls = []
    command = lambda do |argv, timeout|
      @calls << [argv, timeout]
      result
    end
    M2Load::Probe.new(host: "m2", command: command)
  end

  def result(success: true, stdout: "", stderr: "", timed_out: false)
    M2Load::Command::Result.new(success, stdout, stderr, timed_out)
  end

  def test_runs_one_ssh_call_without_prompts_and_with_a_deadline
    probe_answering(result(stdout: FIXTURE)).snapshot
    assert_equal 1, @calls.size
    argv, timeout = @calls.first
    assert_equal "/usr/bin/ssh", argv.first
    assert_includes argv, "BatchMode=yes"
    assert_includes argv, "ConnectTimeout=5"
    assert_equal "m2", argv[-2]
    assert_match(/@@top.*@@vm_stat.*@@sysctl.*@@ps/m, argv.last)
    assert_match(/echo "self \$\$"; exec top .*-n 6/, argv.last)
    assert_equal 10, timeout
  end

  def test_answer_becomes_a_snapshot
    assert_equal 10, probe_answering(result(stdout: FIXTURE)).snapshot.cores
  end

  def test_ssh_failure_reports_the_last_line_of_stderr
    stderr = "Warning: something\nssh: connect to host m2.local port 22: No route to host\n"
    error = assert_raises(M2Load::Unavailable) { probe_answering(result(success: false, stderr: stderr)).snapshot }
    assert_equal "ssh: connect to host m2.local port 22: No route to host", error.message
  end

  def test_ssh_failure_without_stderr_says_ssh_failed
    error = assert_raises(M2Load::Unavailable) { probe_answering(result(success: false, stderr: "\n")).snapshot }
    assert_equal "ssh exited with an error", error.message
  end

  def test_timeout_says_there_was_no_answer
    error = assert_raises(M2Load::Unavailable) { probe_answering(result(success: false, timed_out: true)).snapshot }
    assert_equal "No answer in 10 s", error.message
  end

  def test_incomplete_answer_is_unavailable
    error = assert_raises(M2Load::Unavailable) { probe_answering(result(stdout: fixture_without("ps"))).snapshot }
    assert_equal "Incomplete answer from m2", error.message
  end

  def test_process_names_are_listed_in_utf8
    probe_answering(result(stdout: FIXTURE)).snapshot
    assert_match(/LC_ALL=en_US.UTF-8 ps -Aceo/, @calls.first.first.last)
  end

  def test_non_ascii_noise_in_a_us_ascii_locale_is_ignored
    noisy = ("Привет\n" + FIXTURE).b.force_encoding(Encoding::US_ASCII)
    assert_equal 10, probe_answering(result(stdout: noisy)).snapshot.cores
  end

  def test_non_ascii_ssh_error_reads_as_utf8
    stderr = "ssh: Не удалось\n".b.force_encoding(Encoding::US_ASCII)
    error = assert_raises(M2Load::Unavailable) { probe_answering(result(success: false, stderr: stderr)).snapshot }
    assert_equal "ssh: Не удалось", error.message
  end
end
