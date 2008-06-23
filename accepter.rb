#
#   accepter.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Penta Advanced Laboratories Co.,Ltd)
#
# --
#
#   
#

require "socket"

module DeepConnect
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

    
