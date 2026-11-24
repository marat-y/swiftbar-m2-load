module M2Load
  module Command
    Result = Struct.new(:success, :stdout, :stderr, :timed_out)
    GRACE_SECONDS = 2

    def self.run(argv, timeout)
      Open3.popen3(*argv, pgroup: true) do |stdin, stdout, stderr, waiter|
        stdin.close
        output = Thread.new { stdout.read }
        errors = Thread.new { stderr.read }
        next Result.new(waiter.value.success?, output.value, errors.value, false) if waiter.join(timeout)

        stop(waiter)
        [output, errors].each { |reader| reader.join(GRACE_SECONDS) }
        Result.new(false, "", "", true)
      end
    rescue SystemCallError => error
      Result.new(false, "", error.message, false)
    end

    def self.stop(waiter)
      signal("TERM", waiter.pid)
      signal("KILL", waiter.pid) unless waiter.join(GRACE_SECONDS)
    end

    def self.signal(name, pid)
      Process.kill(name, -pid)
    rescue SystemCallError
      nil
    end
  end
end
