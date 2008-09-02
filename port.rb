#
#   port.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

require "deep-connect/event"

module DeepConnect
  class Port

    PACK_n_SIZE = [1].pack("n").size
    PACK_N_SIZE = [1].pack("N").size

    def initialize(sock)
      @io = sock
      @peeraddr = @io.peeraddr
      @session = nil
    end

    def close
      @io.close
    end

    def shutdown_reading
      @io.shutdown(Socket::SHUT_RD)
    end

    def addr
      @io.addr
    end

    def peeraddr
      @peeraddr
    end

    def attach(session)
      @session = session
    end

    def import
#      puts "IMPORT: start0" 
      sz = read(PACK_N_SIZE).unpack("N").first
      bin = read(sz)
      a = Marshal.load(bin)
      begin
	# ここで, ネットワーク通信発生する可能性あり.
	ev = Event.materialize(@session, a.first, *a)
      rescue
	p $!, $@
	raise
      end
      puts "IMPORT: #{ev.inspect}" if DC::MESSAGE_DISPLAY
      ev
    end

    def export(ev)
      puts "EXPORT: #{ev.inspect}" if DC::MESSAGE_DISPLAY
      bin = Marshal.dump(ev.serialize)
      size = bin.size

      packet = [size].pack("N")+bin
      write(packet)
      puts "EXPORT: finsh" if DC::MESSAGE_DISPLAY
    end

    def read(n)
      begin
	packet = @io.read(n)
	fail EOFError, "socket closed" unless packet
#	DC::Raise ProtocolError unless packet.size == n
	packet
      rescue Errno::ECONNRESET
	puts "WARN: read中に[#{peeraddr.join(', ')}]の接続が切れました"
	DC::Raise DisconnectClient, peeraddr
      end
    end
    
    def write(packet)
      begin
	@io.write(packet)
#	@io.flush
      rescue Errno::ECONNRESET
	puts "WARN: write中に[#{peeraddr.join(', ')}]の接続が切れました"
	DC::Raise DisconnectClient, peeraddr
      end
    end
  end
end

