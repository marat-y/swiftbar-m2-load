ENV["TZ"] = "UTC"

require "minitest/autorun"
require "tmpdir"
require_relative "../lib/m2_load"

module TestSupport
  FIXTURE = File.read(File.expand_path("fixtures/m2_output.txt", __dir__)).freeze
  NOW = Time.utc(2026, 11, 24, 18, 0, 0)

  def fixture_without(section)
    FIXTURE.sub(/^@@#{section}\n(?:(?!@@).*\n)*/, "")
  end
end
