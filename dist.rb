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

require "forwarding"

require "deep-connect/organizer"

module DeepConnect
  @RCS_ID='-$Id:  $-'

  class Dist
    extend Forwarding

    def Dist.start(service)
      dist = new
      dist.start(service)
      dist
    end

    def initialize
      @organizer = Organizer.new
    end

    def_delegator :@organizer, :start
    def_delegator :@organizer, :stop
    def_delegator :@organizer, :register_service
    def_delegator :@organizer, :open_session
  end

  def DeepConnect.start(service = nil)
    Dist.start(service)
  end
end



