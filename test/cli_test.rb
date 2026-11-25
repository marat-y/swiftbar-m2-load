require_relative "test_helper"

class CliTest < Minitest::Test
  include TestSupport

  def run_cli(environment: {}, result: nil, raises: nil, widget: ->(_blocks, _dimmed) { nil })
    @argv = nil
    command = lambda do |argv, _timeout|
      @argv = argv
      raise raises if raises

      result || M2Load::Command::Result.new(true, FIXTURE, "", false)
    end
    output = StringIO.new
    status = M2Load::Cli.new(environment: { "SWIFTBAR_PLUGIN_DATA_PATH" => @dir }.merge(environment), output: output, now: NOW, command: command, widget: widget).run
    assert_equal 0, status
    output.string.split("\n")
  end

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_shows_the_load_and_remembers_when_it_was_seen
    assert_equal "M2 23% · 75%", run_cli.first
    assert_equal NOW, M2Load::LastSeen.new(File.join(@dir, "last_seen")).read
  end

  def test_unavailable_shows_when_it_was_last_seen
    M2Load::LastSeen.new(File.join(@dir, "last_seen")).write(NOW - 240)
    menu = run_cli(result: M2Load::Command::Result.new(false, "", "ssh: connect to host m2 port 22: No route to host\n", false))
    assert_equal "M2 — | color=#8e8e93", menu.first
    assert_includes menu, "Last seen 4 min ago"
    assert_includes menu, "ssh: connect to host m2 port 22: No route to host"
  end

  def test_host_and_label_come_from_the_environment
    menu = run_cli(environment: { "M2_LOAD_HOST" => "studio", "M2_LOAD_LABEL" => "S" })
    assert_equal "studio", @argv[-2]
    assert_equal "S 23% · 75%", menu.first
  end

  def test_title_is_drawn_by_the_widget
    drawn = nil
    widget = lambda do |blocks, _dimmed|
      drawn = blocks
      "IMG"
    end
    assert_equal "| templateImage=IMG", run_cli(environment: { "M2_LOAD_LABEL" => "S" }, widget: widget).first
    assert_equal ["S CPU", "S RAM"], drawn.map(&:first)
  end

  def test_an_unexpected_error_still_renders_a_menu
    menu = run_cli(raises: RuntimeError.new("boom"))
    assert_equal "M2 — | color=#8e8e93", menu.first
    assert_includes menu, "RuntimeError: boom"
  end

  def test_an_unwritable_data_folder_does_not_break_the_menu
    menu = run_cli(environment: { "SWIFTBAR_PLUGIN_DATA_PATH" => "/dev/null/nowhere" })
    assert_equal "M2 23% · 75%", menu.first
  end
end
