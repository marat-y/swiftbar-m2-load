module M2Load
  module Menu
    SEPARATOR = "---".freeze
    UNAVAILABLE_COLOR = "#8e8e93".freeze
    PRESSURE_COLORS = { warning: "orange", critical: "red" }.freeze
    PROCESS_FONT = "font=Menlo size=12 trim=false".freeze
    REFRESH = "Refresh | refresh=true".freeze
    NAME_LIMIT = 40
    VALUE_WIDTH = 6
    GIBIBYTE = 1024.0**3
    MEBIBYTE = 1024.0**2
    AGE_UNITS = [[86_400, "d"], [3600, "h"], [60, "min"], [1, "s"]].freeze
    NO_VALUE = "—".freeze

    def self.reachable(label, snapshot, widget)
      cpu = "#{snapshot.cpu_percent.round}%"
      memory = "#{snapshot.memory_percent.round}%"
      [
        title(widget, blocks(label, cpu, memory), false) || "#{plain(label)} #{cpu} · #{memory}",
        SEPARATOR,
        "CPU #{cpu} · user #{format('%.1f', snapshot.cpu_user)}% · system #{format('%.1f', snapshot.cpu_system)}%",
        "Load average #{snapshot.load_average.map { |value| format('%.2f', value) }.join(' · ')} · #{snapshot.cores} cores",
        "Memory #{gigabytes(snapshot.memory_used)} of #{gigabytes(snapshot.memory_total)} GB · #{memory}",
        pressure_line(snapshot.pressure),
        "Swap #{gigabytes(snapshot.swap_used)} of #{gigabytes(snapshot.swap_total)} GB",
        "Claude processes: #{snapshot.claude_count}",
        SEPARATOR,
        "Top CPU",
        *snapshot.top_cpu.map { |process| process_line(format("%.1f%%", process.value), process.name) },
        SEPARATOR,
        "Top memory",
        *snapshot.top_memory.map { |process| process_line(size(process.value), process.name) },
        SEPARATOR,
        REFRESH,
      ].join("\n") + "\n"
    end

    def self.unavailable(label, reason, last_seen_at, now, widget)
      [
        title(widget, blocks(label, NO_VALUE, NO_VALUE), true) || "#{plain(label)} #{NO_VALUE} | color=#{UNAVAILABLE_COLOR}",
        SEPARATOR,
        "#{plain(label)} is unavailable",
        plain(reason),
        last_seen_at ? last_seen(last_seen_at, now) : "Never seen",
        SEPARATOR,
        REFRESH,
      ].join("\n") + "\n"
    end

    def self.blocks(label, cpu, memory)
      [["#{plain(label)} CPU", cpu], ["#{plain(label)} RAM", memory]]
    end

    def self.title(widget, blocks, dimmed)
      image = widget.call(blocks, dimmed)
      "| templateImage=#{image}" if image
    end

    def self.last_seen(time, now)
      seconds = [(now - time).round, 0].max
      unit_seconds, unit = AGE_UNITS.find { |candidate, _| seconds >= candidate } || AGE_UNITS.last
      "Last seen #{seconds / unit_seconds} #{unit} ago"
    end

    def self.pressure_line(pressure)
      line = "Memory pressure: #{pressure}"
      color = PRESSURE_COLORS[pressure]
      color ? "#{line} | color=#{color}" : line
    end

    def self.process_line(value, name)
      "#{value.rjust(VALUE_WIDTH)}  #{shortened(plain(name))} | #{PROCESS_FONT}"
    end

    def self.shortened(name)
      name.length > NAME_LIMIT ? "#{name[0, NAME_LIMIT - 1]}…" : name
    end

    def self.size(bytes)
      bytes >= GIBIBYTE ? "#{format('%.1f', bytes / GIBIBYTE)} GB" : "#{(bytes / MEBIBYTE).round} MB"
    end

    def self.gigabytes(bytes)
      format("%.1f", bytes / GIBIBYTE)
    end

    def self.plain(text)
      M2Load.utf8(text).gsub(/[[:cntrl:]]+/, " ").tr("|", "¦").strip
    end
  end
end
