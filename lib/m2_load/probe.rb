module M2Load
  class Unavailable < StandardError; end

  class Probe
    SSH = "/usr/bin/ssh".freeze
    SSH_OPTIONS = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=5", "-o", "LogLevel=ERROR"].freeze
    TIMEOUT = 10
    REMOTE_SCRIPT = [
      "export LC_ALL=C",
      "echo @@top", "sh -c 'echo \"self $$\"; exec top -l 2 -s 1 -n 6 -o cpu -stats pid,cpu,command'",
      "echo @@vm_stat", "vm_stat",
      "echo @@sysctl", "sysctl hw.memsize hw.ncpu vm.loadavg vm.swapusage kern.memorystatus_vm_pressure_level",
      "echo @@ps", "ps -Aceo pid=,rss=,comm=",
    ].join("; ").freeze
    SSH_FAILED = "ssh exited with an error".freeze

    def initialize(host:, command: Command.method(:run))
      @host = host
      @command = command
    end

    def snapshot
      result = @command.call([SSH, *SSH_OPTIONS, @host, REMOTE_SCRIPT], TIMEOUT)
      raise Unavailable, "No answer in #{TIMEOUT} s" if result.timed_out
      raise Unavailable, failure_reason(result.stderr) unless result.success

      Snapshot.parse(result.stdout)
    rescue Snapshot::Incomplete
      raise Unavailable, "Incomplete answer from #{@host}"
    end

    private

    def failure_reason(stderr)
      stderr.lines.map(&:strip).reject(&:empty?).last || SSH_FAILED
    end
  end
end
