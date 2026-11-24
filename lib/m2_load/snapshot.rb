module M2Load
  Snapshot = Struct.new(
    :cpu_user, :cpu_system, :load_average, :cores,
    :memory_total, :memory_used, :swap_total, :swap_used, :pressure,
    :top_cpu, :top_memory, :claude_count,
    keyword_init: true
  )

  class Snapshot
    class Incomplete < StandardError; end

    Process = Struct.new(:name, :pid, :value)

    def self.parse(text)
      Report.new(text).snapshot
    end

    def cpu_percent
      cpu_user + cpu_system
    end

    def memory_percent
      memory_used * 100.0 / memory_total
    end
  end
end
