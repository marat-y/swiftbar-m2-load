require_relative "test_helper"
require "zlib"

class WidgetTest < Minitest::Test
  BLOCKS = [["M2 CPU", "23%"], ["M2 RAM", "75%"]].freeze
  OSASCRIPT = "/usr/bin/osascript".freeze
  PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b.freeze

  def fake_command(result)
    lambda do |argv, timeout|
      @argv = argv
      @timeout = timeout
      result
    end
  end

  def render(result, blocks: BLOCKS, dimmed: false)
    M2Load::Widget.render(blocks, dimmed, command: fake_command(result))
  end

  def printed(stdout)
    M2Load::Command::Result.new(true, stdout, "", false)
  end

  def test_runs_the_script_with_the_blocks
    assert_equal "iVBORw0KGgo=", render(printed("iVBORw0KGgo=\n"))
    assert_equal [OSASCRIPT, "-l", "JavaScript", M2Load::Widget::SCRIPT, "normal", "M2 CPU", "23%", "M2 RAM", "75%"], @argv
    assert_equal 3, @timeout
  end

  def test_dimmed_blocks
    render(printed("iVBORw0KGgo=\n"), dimmed: true)
    assert_equal "dimmed", @argv[4]
  end

  def test_failure_gives_no_image
    assert_nil render(M2Load::Command::Result.new(false, "iVBORw0KGgo=\n", "error", false))
    assert_nil render(M2Load::Command::Result.new(false, "", "", true))
  end

  def test_output_that_is_not_base64_gives_no_image
    assert_nil render(printed("warning: something\n"))
    assert_nil render(printed(""))
  end

  def test_output_that_is_not_a_png_gives_no_image
    assert_nil render(printed("null\n"))
  end

  def test_an_error_while_rendering_gives_no_image
    failing = ->(_argv, _timeout) { raise ThreadError, "can't create Thread" }
    assert_nil M2Load::Widget.render(BLOCKS, false, command: failing)
  end

  def test_real_render_has_a_stable_size
    skip "no osascript" unless File.executable?(OSASCRIPT)

    low = png(M2Load::Widget.render([["M2 CPU", "5%"], ["M2 RAM", "5%"]], false))
    high = png(M2Load::Widget.render([["M2 CPU", "100%"], ["M2 RAM", "100%"]], true))
    assert_equal PNG_SIGNATURE, low[0, 8]
    assert_equal 44, pixel_size(low).last
    assert_equal pixel_size(low), pixel_size(high)
  end

  def test_real_render_draws_text_because_an_assigned_current_context_draws_nothing
    skip "no osascript" unless File.executable?(OSASCRIPT)

    image = png(M2Load::Widget.render(BLOCKS, false))
    width, height = pixel_size(image)
    rows = Zlib::Inflate.inflate(idat(image)).bytes.each_slice(width * 4 + 1).to_a
    assert_equal height, rows.size
    assert(rows.any? { |row| row.drop(1).any?(&:nonzero?) })
  end

  def idat(png)
    data = "".b
    offset = 8
    while offset < png.bytesize
      length, type = png[offset, 8].unpack("Na4")
      data << png[offset + 8, length] if type == "IDAT"
      offset += length + 12
    end
    data
  end

  def png(image)
    refute_nil image
    image.unpack1("m0")
  end

  def pixel_size(png)
    png[16, 8].unpack("N2")
  end
end
