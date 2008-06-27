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
require "ipaddr"

require "deep-connect/event"

module DeepConnect
  class Accepter
    def initialize(org)
      @organizer = org
      @probe = nil
    end

    def port_number
      @probe.addr[1]
    end

    def open(service)
      @probe = TCPServer.open(service)
    end

    def start
      @probe_thread = Thread.start {
	loop do
	  sock = @probe.accept
	  port = Port.new(sock)
	  begin
	    unless (ev = port.import).kind_of?(Event::InitSessionEvent)
	      puts "WARN: ��³��������顼: [#{port.peeraddr}]"
	    end
	    @organizer.start_session_on_port port, ev.local_id
	  rescue EOFError
	    puts "WARN: ��³��������[#{port.peeraddr}]�Ȥ���³���ڤ�ޤ���"
	  end
	end
      }
    end

    def stop
      @probe_thread.stop
      @probe.close
    end
  end
end

    
