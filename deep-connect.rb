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

  DISPLAY_METHOD_MISSING = false
  MESSAGE_DISPLAY = false
  DEBUG = false
  DISPLAY_METHOD_SPEC = false

  class DConnect
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
    def_delegator :@organizer, :export
    def_delegator :@organizer, :register_service
    def_delegator :@organizer, :open_deep_space
    def_delegator :@organizer, :open_deepspace
    def_delegator :@organizer, :local_id
    def_delegator :@organizer, :local_id
  end

  def DeepConnect.start(service = nil)
    DConnect.start(service)
  end

  def DeepConnect.def_method_spec(*opts)
    Organizer.def_method_spec(*opts)
  end

  def DeepConnect.def_single_method_spec(*opts)
    Organizer.def_single_method_spec(*opts)
  end

end

require "deep-connect/serialize"





