module M2Load
  class LastSeen
    def initialize(path)
      @path = path
    end

    def read
      Time.iso8601(File.read(@path).strip)
    rescue SystemCallError, ArgumentError
      nil
    end

    def write(time)
      FileUtils.mkdir_p(File.dirname(@path))
      temporary = "#{@path}.#{Process.pid}.tmp"
      File.write(temporary, time.iso8601)
      File.rename(temporary, @path)
    rescue SystemCallError
      nil
    end
  end
end
