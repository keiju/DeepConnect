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
		puts "WARN: 接続初期化エラー: [#{port.peeraddr}]"
	      end
	      begin
		@organizer.connect_deep_space_with_port port, ev.local_id
	      rescue ConnectCancel
		puts "INFO: クライアント(#{ev.local_id}からの接続を拒否しました."
	      rescue ConnectionRefused
		puts "WARN: クライアント(#{ev.local_id}への接続が拒否されました"
	      rescue ProtocolError, IOError
		puts "WARN: 接続初期化エラー: [#{port.peeraddr}]"

	      end
	    rescue EOFError
	      puts "WARN: 接続初期化中に[#{port.peeraddr}]との接続が切れました"
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

    
