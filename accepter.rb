#!/usr/local/bin/ruby
#
#   accepter.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Nihon Rational Software Co.,Ltd)
#
# --
#
#   
#

require "socket"

module DIST

  class Accepter
    def initialize(org)
      @organizer = org
      @probe = nil
    end

    def open(service)
      @probe = TCPServer.open(service)
    end

    def start
      @probe_thread = Thread.start {
	loop do
	  sock = @probe.accept
	  port = Port.new(sock)
	  @organizer.register_session_on_port port
	end
      }
    end

    def stop
      @probe_thread.stop
      @probe.close
    end
  end
end

    
