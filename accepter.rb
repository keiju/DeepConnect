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

require "event"

module DeepConnect
  class Accepter
    def initialize(org)
      @organizer = org
      @probe = nil
    end

#     def uuid
#       addr, port = @probe.addr.values_at(3,1)
# p      ipaddr = IPAddr.new(addr)
#       ipaddr = ipaddr.ipv4_mapped if ipaddr.ipv4?
#       [ipaddr.to_s, port]
#     end

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
	  unless (ev = port.import).kind_of?(Event::InitSessionEvent)
	    raise "プロトコルエラー"
	  end
	  @organizer.register_session_on_port port, ev.local_id
	end
      }
    end

    def stop
      @probe_thread.stop
      @probe.close
    end
  end
end

    
