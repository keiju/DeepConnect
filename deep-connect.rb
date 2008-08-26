#
#   dist.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

require "forwardable"

require "deep-connect/organizer"

module DeepConnect
  @RCS_ID='-$Id:  $-'

  # DC is a internal using short cut of DeepConnect .
  DC = DeepConnect

  DISPLAY_MESSAGE_TRACE = false
  MESSAGE_DISPLAY = false
  DEBUG = true
  DISPLAY_METHOD_SPEC = false
  DISPLAY_MONITOR_MESSAGE = false
  DISPLAY_KEEP_ALIVE = false

  DEBUG_REFERENCE = false
  DISPLAY_GC = false

#  KEEP_ALIVE_INTERVAL = 60

  class DeepConnect
    extend Forwardable

    def self.start(service=0)
      dc = new
      dc.start(service)
      dc
    end

    def initialize
      @organizer = Organizer.new
    end

    def_delegator :@organizer, :start
    def_delegator :@organizer, :stop

    def_delegator :@organizer, :open_deep_space
    def_delegator :@organizer, :open_deepspace
    def_delegator :@organizer, :close_deep_space
    def_delegator :@organizer, :close_deepspace
    def_delegator :@organizer, :when_connected

    def_delegator :@organizer, :export
    def_delegator :@organizer, :register_service
    def_delegator :@organizer, :release_object

    def_delegator :@organizer, :local_id
  end

  def DC.start(service = nil)
    DeepConnect.start(service)
  end

  def DC.def_method_spec(*opts)
    Organizer.def_method_spec(*opts)
  end

  def DC.def_single_method_spec(*opts)
    Organizer.def_single_method_spec(*opts)
  end

  def DC.def_interface(*opts)
    Organizer.def_interface(*opts)
  end

  def DC.def_single_interface(*opts)
    Organizer.def_single_interface(*opts)
  end

end

require "deep-connect/serialize"





