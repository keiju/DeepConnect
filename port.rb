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
p "CLOSE"
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
      sz = read(PACK_N_SIZE).unpack("N").first
      bin = read(sz)
#      puts "IMPORT: start" if DC::MESSAGE_DISPLAY
      a = Marshal.load(bin)
#      puts "IMPORT: serialize start" if DC::MESSAGE_DISPLAY
#      p a
      ev = Event.materialize(@session, a.first, *a)
#      puts "XXXXXXX"
      puts "IMPORT: #{ev.inspect}" if DC::MESSAGE_DISPLAY
#       if :output == ev.instance_eval{@method} && ev.kind_of?(Event::Reply)
# 	if !ev.result.__deep_connect_reference?
# 	  puts "IMPORT 1: #{a.inspect}"
# 	  puts "IMPORT 2: #{ev.inspect}"
# 	  $FOO = Thread.current
# 	  ev2 = Event.materialize(@session, a.first, *a)
# 	  puts "IMPORT 2: #{ev2.inspect}"
# 	  $FOO = 0
# 	end
#       end
      ev
    end

    def export(ev)
      puts "EXPORT: #{ev.inspect}" if DC::MESSAGE_DISPLAY
#      p ev.serialize
      bin = Marshal.dump(ev.serialize)
#       if /output/ =~ ev.instance_eval{@method}
# 	puts "EXPORT 1: #{ev.inspect}" 
# 	puts "EXPORT 2: #{Marshal.load(bin).inspect}"
#       end
      size = bin.size

      packet = [size].pack("N")+bin
      write(packet)
      puts "EXPORT: finsh" if DC::MESSAGE_DISPLAY
    end

#     def import
#       sz = read(PACK_N_SIZE).unpack("N").first
#       bin = read(sz).unpack("a#{sz}")
#       a = Marshal.load(bin.first)
#       ev = Event.materialize(@session, a.first, *a)
#       puts "IMPORT: #{ev.inspect}" if DC::MESSAGE_DISPLAY
#       ev
#     end

#     def export(ev)
#       puts "EXPORT: #{ev.inspect}" if DC::MESSAGE_DISPLAY
#       s = Marshal.dump(ev.serialize)
#       size = s.size
#       packet = [size, s].pack("Na#{size}")
#       write(packet)
#     end

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
      rescue Errno::ECONNRESET
	puts "WARN: write中に[#{peeraddr.join(', ')}]の接続が切れました"
	DC::Raise DisconnectClient, peeraddr
      end
    end
  end
end

