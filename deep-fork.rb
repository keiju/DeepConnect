
require "thread"

module DeepConnect

  class DeepFork

    def initialize(dc1, service = 0, except_closing_io = [STDIN, STDOUT, STDERR], &block)
      @dc1 = dc1

      @peer_pid = nil
      @peer_deep_space = nil
      @peer_deep_space_mx = Mutex.new
      @peer_deep_space_cv = ConditionVariable.new

      exp = "DeepFork_#{format("%0xd", self.object_id)}"
      @dc1.export(exp, self)

      @peer_pid = Process.fork {
	ionos = except_closing_io.collect{|io| io.fileno}

	ObjectSpace.each_object(IO) do |io|
	  begin
	    unless ionos.include?(io.fileno)
	      io.close
	    end
	  rescue
	  end
	end
	dc2 = DeepConnect.start(service)
	ds2 = dc2.open_deepspace("localhost", @dc1.local_id)
	df1 = ds2.import(exp)
	df1.connect(self, $$)
	block.call(dc2, ds2)
      }

      @peer_deep_space_mx.synchronize do
	until @peer_deep_space
	  @peer_deep_space_cv.wait(@peer_deep_space_mx)
	end
      end
      self
    end
    
    attr_reader :peer_deep_space
    attr_reader :peer_pid

    def connect(df2, peer_pid)
      @peer_deep_space_mx.synchronize do
	if @peer_pid == peer_pid
	  @peer_deep_space = df2.deep_space
	  @peer_deep_space_cv.signal
	end
      end
    end

    class <<self
      alias fork new
    end
  end
end
