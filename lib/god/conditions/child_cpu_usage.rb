module God
  module Conditions
    
    # Condition Symbol :cpu_usage
    # Type: Poll
    # 
    # Trigger when the percent of CPU use of a process is above a specified limit.
    # On multi-core systems, this number could conceivably be above 100.
    #
    # Paramaters
    #   Required
    #     +pid_file+ is the pid file of the process in question. Automatically
    #                populated for Watches.
    #     +above+ is the percent CPU above which to trigger the condition. You 
    #             may use #percent to clarify this amount (see examples).
    #
    # Examples
    #
    # Trigger if the process is using more than 25 percent of the cpu (from a Watch):
    #
    #   on.condition(:cpu_usage) do |c|
    #     c.above = 25.percent
    #   end
    #
    # Non-Watch Tasks must specify a PID file:
    #
    #   on.condition(:cpu_usage) do |c|
    #     c.above = 25.percent
    #     c.pid_file = "/var/run/mongrel.3000.pid"
    #   end
    class ChildCpuUsage < PollCondition
      attr_accessor :above, :times, :pid_file
    
      def initialize
        super
        self.above = nil
        self.times = [1, 1]
      end
      
      def prepare
        if self.times.kind_of?(Integer)
          self.times = [self.times, self.times]
        end
        
        @timeline = Timeline.new(self.times[1])
      end
      
      def reset
        @timeline.clear
      end
      
      def pid
        self.pid_file ? File.read(self.pid_file).strip.to_i : self.watch.pid
      end
      
      def valid?
        valid = true
        valid &= complain("Attribute 'pid_file' must be specified", self) if self.pid_file.nil? && self.watch.pid_file.nil?
        valid &= complain("Attribute 'above' must be specified", self) if self.above.nil?
        valid
      end
      
      def test
        process = System::Process.new(self.pid)
        descendant_pids = Array.new
        all_descendants(descendant_pids, self.pid)
        
        total_cpu = process.percent_cpu
        descendant_pids.each do |pid|
          sub_process = System::Process.new(pid)
          total_cpu += sub_process.percent_cpu
        end
        
        @timeline.push(total_cpu)
        
        history = "[" + @timeline.map { |x| "#{x > self.above ? '*' : ''}#{x}%%" }.join(", ") + "]"
        
        if @timeline.select { |x| x > self.above }.size >= self.times.first
          self.info = "cpu out of bounds #{history}"
          return true
        else
          self.info = "cpu within bounds #{history}"
          return false
        end
      end
      
      
      def all_descendants(descendants, parent_id)
        pipe = IO.popen("ps -o pid,ppid ax|grep #{parent_id}")
        lines = pipe.readlines
        return if lines.size < 2
        lines.each do |line|
          parts = line.strip.split(/\s+/)
          # puts parts.inspect
          if(parts[1].to_i == parent_id) then
            descendants.push parts[0].to_i
            all_descendants(descendants, parts[0].to_i)
          end
        end
      end
      
      
    end
    
  end
end


