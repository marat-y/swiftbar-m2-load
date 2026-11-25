require_relative "test_helper"

class MenuTest < Minitest::Test
  include TestSupport

  NO_IMAGE = ->(_blocks, _dimmed) { nil }

  def recording_widget(image)
    lambda do |blocks, dimmed|
      @widget_call = [blocks, dimmed]
      image
    end
  end

  def snapshot(text = FIXTURE)
    M2Load::Snapshot.parse(text)
  end

  def lines(menu)
    menu.split("\n")
  end

  def reachable(text = FIXTURE, label: "M2", widget: NO_IMAGE)
    lines(M2Load::Menu.reachable(label, snapshot(text), widget))
  end

  def unavailable(reason = "No answer in 10 s", last_seen_at = NOW - 240, widget: NO_IMAGE)
    lines(M2Load::Menu.unavailable("M2", reason, last_seen_at, NOW, widget))
  end

  def test_title_is_the_widget_image
    assert_equal "| templateImage=IMG", reachable(widget: recording_widget("IMG")).first
    assert_equal [[["M2 CPU", "23%"], ["M2 RAM", "75%"]], false], @widget_call
  end

  def test_title_falls_back_to_text_without_an_image
    assert_equal "M2 23% · 75%", reachable.first
  end

  def test_label_in_captions_is_plain
    reachable(label: "a\tb|c", widget: recording_widget("IMG"))
    assert_equal ["a b¦c CPU", "a b¦c RAM"], @widget_call.first.map(&:first)
  end

  def test_dropdown_shows_cpu_load_memory_swap_and_claude
    menu = reachable
    assert_includes menu, "CPU 23% · user 14.5% · system 8.4%"
    assert_includes menu, "Load average 2.84 · 2.33 · 2.20 · 10 cores"
    assert_includes menu, "Memory 12.0 of 16.0 GB · 75%"
    assert_includes menu, "Memory pressure: normal"
    assert_includes menu, "Swap 2.4 of 4.0 GB"
    assert_includes menu, "Claude processes: 3"
  end

  def test_memory_pressure_above_normal_is_coloured
    warning = reachable(FIXTURE.sub("pressure_level: 1", "pressure_level: 2"))
    critical = reachable(FIXTURE.sub("pressure_level: 1", "pressure_level: 4"))
    assert_includes warning, "Memory pressure: warning | color=orange"
    assert_includes critical, "Memory pressure: critical | color=red"
  end

  def test_top_processes_by_cpu_and_memory
    menu = reachable
    cpu = menu.index("Top CPU")
    memory = menu.index("Top memory")
    assert_match(/\A 97\.5%  com\.apple\.Virtualization\.VirtualMachine \| font=Menlo size=12 trim=false\z/, menu[cpu + 1])
    assert_match(/\A1\.4 GB  com\.apple\.Virtualization\.VirtualMachine \| font=Menlo size=12 trim=false\z/, menu[memory + 1])
    assert_match(/\A527 MB  claude \|/, menu[memory + 2])
    assert_equal 5, menu[(memory + 1)..-1].take_while { |line| line != "---" }.size
  end

  def test_process_names_cannot_break_swiftbar_parameters
    text = FIXTURE.sub("Google Chrome Helper (Renderer)", "evil | color=red").sub("61000 401408", "61000 9401408")
    line = reachable(text).find { |candidate| candidate.include?("evil") }
    assert_match(/\A9\.0 GB  evil ¦ color=red \| font=Menlo size=12 trim=false\z/, line)
  end

  def test_long_process_names_are_shortened
    text = FIXTURE.sub("Google Chrome Helper (Renderer)", "x" * 60).sub("61000 401408", "61000 9401408")
    line = reachable(text).find { |candidate| candidate.include?("xxx") }
    assert_includes line, "#{'x' * 39}…"
  end

  def test_refresh_item
    assert_equal "Refresh | refresh=true", reachable.last
  end

  def test_unavailable_title_is_a_dimmed_widget
    assert_equal "| templateImage=IMG", unavailable(widget: recording_widget("IMG")).first
    assert_equal [[["M2 CPU", "—"], ["M2 RAM", "—"]], true], @widget_call
  end

  def test_unavailable_title_falls_back_to_grey_dash
    menu = unavailable
    assert_equal "M2 — | color=#8e8e93", menu.first
    assert_includes menu, "M2 is unavailable"
    assert_includes menu, "No answer in 10 s"
    assert_includes menu, "Last seen 4 min ago"
    assert_equal "Refresh | refresh=true", menu.last
  end

  def test_unavailable_never_seen
    menu = unavailable("No answer in 10 s", nil)
    assert_includes menu, "Never seen"
  end

  def test_last_seen_ages
    assert_equal "Last seen 15 s ago", M2Load::Menu.last_seen(NOW - 15, NOW)
    assert_equal "Last seen 2 h ago", M2Load::Menu.last_seen(NOW - 7300, NOW)
    assert_equal "Last seen 3 d ago", M2Load::Menu.last_seen(NOW - 3 * 86_400, NOW)
  end

  def test_unavailable_reason_cannot_break_swiftbar_parameters
    menu = unavailable("bad | bash=/bin/rm", nil)
    assert_includes menu, "bad ¦ bash=/bin/rm"
  end

  def test_non_ascii_label_from_a_us_ascii_environment
    label = "М2".b.force_encoding(Encoding::US_ASCII)
    assert_equal "М2 — | color=#8e8e93", lines(M2Load::Menu.unavailable(label, "x", nil, NOW, NO_IMAGE)).first
  end
end
