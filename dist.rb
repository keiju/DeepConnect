#!/usr/local/bin/ruby
#
#   dist.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Nihon Rational Software Co.,Ltd)
#
# --
#
#   
#
require "forwarding"

require "dist/organizer"

module DIST
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

  def DIST.start(service = nil)
    Dist.start(service)
  end
end



