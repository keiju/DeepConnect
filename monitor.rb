#
#   monitor.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

@RCS_ID='-$Id:  $-'

module DeepConnect
  class Monitor

    def initialize(organizer)
      @organizer = organizer

      @timer = 0
      @counter10s = 0
      @counter1m = 0
      @counter1h = 0
      
      @mon_mutex = Mutex.new

      @prev_message10s = nil
    end

    MON_INTERVAL = 1

    def start
      Thread.start do 
	loop do
	  sleep MON_INTERVAL
	  @timer += MON_INTERVAL
	  
	  Thread.start do
	    @mon_mutex.synchronize do
	      @counter10s += MON_INTERVAL
	      @counter1m += MON_INTERVAL
	      @counter1h += MON_INTERVAL

	      if @counter10s >= 1
		@counter10s = 0
		mon_10sec 
	      end
	      if @counter1m >= 60
		@counter1m = 0
		mon_min
	      end
	      if @counter1h >= 3600
		@counter1h = 0
		mon_hour
	      end
	    end
	  end
	end
      end
    end

    def mon_10sec
      return if @organizer.deep_spaces.size == 0

      if DISPLAY_MONITOR_MESSAGE
	str = ""
	str.concat "Connect DeepSpaces: BEGIN\n"
	for peer_id, ds in @organizer.deep_spaces.dup
	  str.concat "#{peer_id.inspect} => \n"
	  str.concat "\t#{ds}\n"
	end
	str.concat "Connect DeepSpaces: END\n"

	if @prev_message10s != str
	  @prev_message10s = str
	  puts "MON 10SEC: #{@timer}\n", str
	end
      end
    end

    def mon_min
      if DISPLAY_MONITOR_MESSAGE
	puts "MON MIN: #{@timer}"
      end
    end

    def mon_hour
      if DISPLAY_MONITOR_MESSAGE
	puts "MON HOUR: #{@timer}"
      end
    end
  end
end



