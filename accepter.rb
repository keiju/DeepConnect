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

    def open(service = 0)
      @probe = TCPServer.open("", service)
    end

    def start
      @probe_thread = Thread.start {
	loop do
	  sock = @probe.accept
	  Thread.start do
	    port = Port.new(sock)
	    begin
	      unless (ev = port.import).kind_of?(Event::InitSessionEvent)
		puts "WARN: ��³��������顼: [#{port.peeraddr}]"
	      end
	      begin
		@organizer.connect_deep_space_with_port port, ev.local_id
	      rescue ConnectCancel
		puts "INFO: ���饤�����(#{ev.local_id}�������³����ݤ��ޤ���."
	      rescue ConnectionRefused
		puts "WARN: ���饤�����(#{ev.local_id}�ؤ���³�����ݤ���ޤ���"
	      rescue ProtocolError, IOError
		puts "WARN: ��³��������顼: [#{port.peeraddr}]"

	      end
	    rescue EOFError
	      puts "WARN: ��³��������[#{port.peeraddr}]�Ȥ���³���ڤ�ޤ���"
	    end
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

    
