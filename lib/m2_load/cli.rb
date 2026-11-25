module M2Load
  class Cli
    DEFAULT_HOST = "m2".freeze
    DEFAULT_LABEL = "M2".freeze
    DEFAULT_DATA_DIR = File.join(Dir.home, "Library", "Application Support", "swiftbar-m2-load").freeze

    def initialize(environment: ENV, output: $stdout, now: Time.now, command: Command.method(:run), widget: Widget.method(:render))
      @environment = environment
      @output = output
      @now = now
      @command = command
      @widget = widget
    end

    def run
      snapshot = Probe.new(host: host, command: @command).snapshot
      last_seen.write(@now)
      @output.print(Menu.reachable(label, snapshot, @widget))
      0
    rescue Unavailable => error
      unavailable(error.message)
    rescue StandardError => error
      unavailable("#{error.class}: #{error.message}")
    end

    private

    def unavailable(reason)
      @output.print(Menu.unavailable(label, reason, last_seen.read, @now, @widget))
      0
    end

    def host
      @environment["M2_LOAD_HOST"] || DEFAULT_HOST
    end

    def label
      @environment["M2_LOAD_LABEL"] || DEFAULT_LABEL
    end

    def last_seen
      LastSeen.new(File.join(@environment["SWIFTBAR_PLUGIN_DATA_PATH"] || DEFAULT_DATA_DIR, "last_seen"))
    end
  end
end
