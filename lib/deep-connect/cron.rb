# encoding: UTF-8
#
#   cron.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
#

@RCS_ID='-$Id:  $-'

module DeepConnect

  class Cron

    TAB = [
      [10, proc{|org, cron, t| cron.mon_10sec}],
      [60, proc{|org, cron, t| cron.mon_min}],
      [3060, proc{|org, cron, t| cron.mon_hour}],
      [Conf.KEEP_ALIVE_INTERVAL, proc{|org, cron, t| org.keep_alive}],
    ]

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
	  sleep Conf.MON_INTERVAL
	  @timer += Conf.MON_INTERVAL
	  
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

      if Conf.DISPLAY_MONITOR_MESSAGE
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
      if Conf.DISPLAY_MONITOR_MESSAGE
	puts "MON MIN: #{@timer}"
      end
    end

    def mon_hour
      if Conf.DISPLAY_MONITOR_MESSAGE
	puts "MON HOUR: #{@timer}"
      end
    end
  end
end



