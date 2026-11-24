require_relative "test_helper"

class SnapshotTest < Minitest::Test
  include TestSupport

  def snapshot
    @snapshot ||= M2Load::Snapshot.parse(FIXTURE)
  end

  def test_cpu_comes_from_the_second_top_sample
    assert_in_delta 14.53, snapshot.cpu_user, 0.001
    assert_in_delta 8.42, snapshot.cpu_system, 0.001
    assert_in_delta 22.95, snapshot.cpu_percent, 0.001
  end

  def test_load_average_and_cores
    assert_equal [2.84, 2.33, 2.20], snapshot.load_average
    assert_equal 10, snapshot.cores
  end

  def test_memory_used_counts_like_stats
    pages = 317_581 + 313_513 + 3032 + 115_561 + 254_498 - 1214 - 213_539
    assert_equal pages * 16_384, snapshot.memory_used
    assert_equal 17_179_869_184, snapshot.memory_total
    assert_in_delta 75.29, snapshot.memory_percent, 0.01
  end

  def test_swap
    assert_equal 4096 * 1_048_576, snapshot.swap_total
    assert_in_delta 2490.38 * 1_048_576, snapshot.swap_used, 1
  end

  def test_pressure_levels
    assert_equal :normal, snapshot.pressure
    assert_equal :warning, with_pressure(2).pressure
    assert_equal :critical, with_pressure(4).pressure
  end

  def test_top_cpu_names_come_from_ps_not_from_the_truncated_top_column
    first = snapshot.top_cpu.first
    assert_equal "com.apple.Virtualization.VirtualMachine", first.name
    assert_equal 52_106, first.pid
    assert_in_delta 97.5, first.value, 0.001
    assert_equal "claude", snapshot.top_cpu[3].name
  end

  def test_top_cpu_falls_back_to_the_top_name_for_a_process_ps_did_not_list
    assert_equal "kernel_task", snapshot.top_cpu.last.name
  end

  def test_top_cpu_falls_back_to_the_pid_when_no_name_is_known
    text = FIXTURE.sub("0      15.2 kernel_task     ", "999    15.2 ")
    assert_equal "pid 999", M2Load::Snapshot.parse(text).top_cpu.last.name
  end

  def test_top_memory_lists_five_largest_processes_by_resident_size
    top = snapshot.top_memory
    assert_equal 5, top.size
    assert_equal ["com.apple.Virtualization.VirtualMachine", "claude", "ruby", "claude", "claude"], top.map(&:name)
    assert_equal 1_465_408 * 1024, top.first.value
  end

  def test_process_names_keep_their_spaces
    text = FIXTURE.sub("61000 401408", "61000 9401408")
    assert_equal "Google Chrome Helper (Renderer)", M2Load::Snapshot.parse(text).top_memory.first.name
  end

  def test_counts_claude_processes_by_exact_name
    assert_equal 3, snapshot.claude_count
  end

  def test_text_before_the_first_section_is_ignored
    assert_equal 10, M2Load::Snapshot.parse("Welcome\n@@top\n#{FIXTURE.split("@@top\n", 2).last}").cores
  end

  def test_a_missing_section_is_incomplete
    assert_raises(M2Load::Snapshot::Incomplete) { M2Load::Snapshot.parse(fixture_without("vm_stat")) }
  end

  def test_a_section_cut_short_is_incomplete
    assert_raises(M2Load::Snapshot::Incomplete) { M2Load::Snapshot.parse(FIXTURE.split("@@sysctl").first + "@@sysctl\nhw.memsize: 1\n@@ps\n") }
  end

  def test_empty_output_is_incomplete
    assert_raises(M2Load::Snapshot::Incomplete) { M2Load::Snapshot.parse("") }
  end

  private

  def with_pressure(level)
    M2Load::Snapshot.parse(FIXTURE.sub("kern.memorystatus_vm_pressure_level: 1", "kern.memorystatus_vm_pressure_level: #{level}"))
  end
end
