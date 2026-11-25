module M2Load
  module Widget
    SCRIPT = File.join(__dir__, "widget.js").freeze
    OSASCRIPT = "/usr/bin/osascript".freeze
    TIMEOUT = 3
    BASE64 = %r{\A[A-Za-z0-9+/]+={0,2}\z}.freeze

    def self.render(blocks, dimmed, command: Command.method(:run))
      argv = [OSASCRIPT, "-l", "JavaScript", SCRIPT, dimmed ? "dimmed" : "normal", *blocks.flatten]
      result = command.call(argv, TIMEOUT)
      image = M2Load.utf8(result.stdout).strip
      image if result.success && image.match?(BASE64)
    end
  end
end
