#
#   cron.rb - 
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

require "deep-connect/deep-connect"

module DeepConnect

  KEEP_ALIVE_INTERVAL = 60

  class Cron

    TAB = [
      [10, proc{|org, cron, t| cron.mon_10sec}],
      [60, proc{|org, cron, t| cron.mon_min}],
      [3060, proc{|org, cron, t| cron.mon_hour}],
      [KEEP_ALIVE_INTERVAL, proc{|org, cron, t| org.keep_alive}],
    ]

    MON_INTERVAL = 1

    def initialize(organizer)
      @organizer = organizer

      @timer = 0
      @last_exec_times = {}

      @mon_mutex = Mutex.new

      @prev_message10s = nil
    end

    attr_reader :timer
    alias tick timer

    def start
      Thread.start do 
	loop do
	  sleep MON_INTERVAL
	  @timer += MON_INTERVAL
	  
	  Thread.start do
	    @mon_mutex.synchronize do
	      for tab in TAB
		last_time = @last_exec_times[tab]
		last_time = 0 unless last_time
		if @timer >= last_time + tab[0] 
		  @last_exec_times[tab] = @timer
		  tab[1].call @organizer, self, @timer
		end
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



