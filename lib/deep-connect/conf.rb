# encoding: UTF-8
#
#   conf.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

module DeepConnect
  class Config
    def initialize

      # enable distributed garbage collection.
      @ENABLE_GC = false

      @KEEP_ALIVE_INTERVAL = 60
      @MON_INTERVAL = 10

      # debugging attributes.
      @DISABLE_INFO = false

      @DISPLAY_MESSAGE_TRACE = false
      @MESSAGE_DISPLAY = false
      @DEBUG = false
      @DISPLAY_METHOD_SPEC = false
      @DISPLAY_MONITOR_MESSAGE = false
      @DISPLAY_KEEP_ALIVE = false

      @DEBUG_REFERENCE = false
      @DISPLAY_GC = false
    end

    attr_accessor :ENABLE_GC
    attr_accessor :KEEP_ALIVE_INTERVAL
    attr_accessor :MON_INTERVAL

    attr_accessor :DISPLAY_MESSAGE_TRACE
    attr_accessor :MESSAGE_DISPLAY
    attr_accessor :DEBUG
    attr_accessor :DISPLAY_METHOD_SPEC
    attr_accessor :DISPLAY_MONITOR_MESSAGE
    attr_accessor :DISPLAY_KEEP_ALIVE

    attr_accessor :DEBUG_REFERENCE
    attr_accessor :DISPLAY_GC

    attr_accessor :DISABLE_INFO
  end
end
