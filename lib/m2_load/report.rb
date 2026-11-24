module M2Load
  class Report
    SECTIONS = %w[top vm_stat sysctl ps].freeze
    SECTION_MARK = /\A@@(\w+)\s*\z/.freeze
    CPU_USAGE = /CPU usage: ([\d.]+)% user, ([\d.]+)% sys/.freeze
    TOP_HEADER = /\A\s*PID\s+%CPU/.freeze
    TOP_PROCESS = /\A\s*(\d+)\s+([\d.]+)\s*(.*?)\s*\z/.freeze
    PS_PROCESS = /\A\s*(\d+)\s+(\d+)\s(.*?)\s*\z/.freeze
    PAGE_SIZE = /page size of (\d+) bytes/.freeze
    SWAP = /total = ([\d.]+)M\s+used = ([\d.]+)M/.freeze
    COUNTED_PAGES = ["Pages active", "Pages inactive", "Pages speculative", "Pages wired down", "Pages occupied by compressor"].freeze
    RECLAIMABLE_PAGES = ["Pages purgeable", "File-backed pages"].freeze
    PRESSURE_LEVELS = { 2 => :warning, 4 => :critical }.freeze
    TOP_COUNT = 5
    KIBIBYTE = 1024
    MEBIBYTE = 1_048_576
    CLAUDE = "claude".freeze

    def initialize(text)
      @sections = split(text)
      missing = SECTIONS - @sections.keys
      raise Snapshot::Incomplete, "no #{missing.join(', ')}" unless missing.empty?
    end

    def snapshot
      user, system = cpu_usage
      swap_total, swap_used = swap
      Snapshot.new(
        cpu_user: user, cpu_system: system,
        load_average: load_average, cores: Integer(sysctl("hw.ncpu")),
        memory_total: Integer(sysctl("hw.memsize")), memory_used: memory_used,
        swap_total: swap_total, swap_used: swap_used, pressure: pressure,
        top_cpu: top_cpu, top_memory: top_memory,
        claude_count: processes.count { |process| process.name == CLAUDE }
      )
    rescue ArgumentError, TypeError => error
      raise Snapshot::Incomplete, error.message
    end

    private

    def split(text)
      sections = {}
      current = nil
      text.each_line do |line|
        mark = line.match(SECTION_MARK)
        if mark
          current = sections[mark[1]] = []
        elsif current
          current << line.chomp
        end
      end
      sections
    end

    def cpu_usage
      line = @sections["top"].reverse.find { |candidate| candidate.match?(CPU_USAGE) }
      raise Snapshot::Incomplete, "no CPU usage" unless line

      line.match(CPU_USAGE).captures.map { |value| Float(value) }
    end

    def top_cpu
      last_header = @sections["top"].rindex { |line| line.match?(TOP_HEADER) }
      raise Snapshot::Incomplete, "no top processes" unless last_header

      rows = @sections["top"].drop(last_header + 1).map { |line| line.match(TOP_PROCESS) }.compact
      rows.first(TOP_COUNT).map do |row|
        pid = Integer(row[1])
        Snapshot::Process.new(process_name(pid, row[3]), pid, Float(row[2]))
      end
    end

    def process_name(pid, top_name)
      listed = processes.find { |process| process.pid == pid }
      return listed.name if listed
      return top_name unless top_name.empty?

      "pid #{pid}"
    end

    def top_memory
      processes.sort_by { |process| -process.value }.first(TOP_COUNT)
    end

    def processes
      @processes ||= begin
        rows = @sections["ps"].map { |line| line.match(PS_PROCESS) }.compact
        raise Snapshot::Incomplete, "no processes" if rows.empty?

        rows.map { |row| Snapshot::Process.new(row[3], Integer(row[1]), Integer(row[2]) * KIBIBYTE) }
      end
    end

    def memory_used
      pages = COUNTED_PAGES.sum { |key| vm_pages(key) } - RECLAIMABLE_PAGES.sum { |key| vm_pages(key) }
      pages * page_size
    end

    def page_size
      header = @sections["vm_stat"].find { |line| line.match?(PAGE_SIZE) }
      raise Snapshot::Incomplete, "no page size" unless header

      Integer(header.match(PAGE_SIZE)[1])
    end

    def vm_pages(key)
      @vm_stat ||= key_values(@sections["vm_stat"])
      Integer(@vm_stat.fetch(key) { raise Snapshot::Incomplete, "no #{key}" }.chomp("."))
    end

    def sysctl(key)
      @sysctl ||= key_values(@sections["sysctl"])
      @sysctl.fetch(key) { raise Snapshot::Incomplete, "no #{key}" }
    end

    def key_values(lines)
      lines.each_with_object({}) do |line, values|
        key, value = line.split(":", 2)
        values[key.strip] = value.strip if value
      end
    end

    def load_average
      values = sysctl("vm.loadavg").scan(/[\d.]+/).map { |value| Float(value) }
      raise Snapshot::Incomplete, "no load average" unless values.size == 3

      values
    end

    def swap
      match = sysctl("vm.swapusage").match(SWAP)
      raise Snapshot::Incomplete, "no swap usage" unless match

      match.captures.map { |value| (Float(value) * MEBIBYTE).round }
    end

    def pressure
      PRESSURE_LEVELS.fetch(Integer(sysctl("kern.memorystatus_vm_pressure_level")), :normal)
    end
  end
end
