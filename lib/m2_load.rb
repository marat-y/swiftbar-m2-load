require "open3"
require "time"
require "fileutils"

module M2Load
  def self.utf8(text)
    text.to_s.dup.force_encoding(Encoding::UTF_8).scrub("?")
  end
end

require_relative "m2_load/snapshot"
require_relative "m2_load/report"
require_relative "m2_load/command"
require_relative "m2_load/probe"
require_relative "m2_load/last_seen"
require_relative "m2_load/menu"
require_relative "m2_load/cli"
