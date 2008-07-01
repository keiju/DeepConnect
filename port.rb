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

require "e2mmap"

require "deep-connect/event"

module DeepConnect
  class Port
    extend Exception2MessageMapper

    def_exception :ProtocolError, "Protocol error!!"
    def_exception :DisconnectClient, "%sの接続が切れました"

    PacketId2Class = [
      Event::Event, 
      Event::Request, 
      Event::IteratorRequest, 
      Event::IteratorNextRequest, 
#      Event::IteratorRetryRequest, 
      Event::IteratorExitRequest, 
      Event::SessionRequest,
      Event::SessionRequestNoReply,
      Event::Reply, Event::IteratorReply, Event::IteratorReplyFinish, 
      Event::SessionReply,
      Event::InitSessionEvent
    ]
    Class2PacketId = {}
    PacketId2Class.each_with_index do
      |p, idx|
      Class2PacketId[p] = idx
    end

    PACK_n_SIZE = [1].pack("n").size
    PACK_N_SIZE = [1].pack("N").size

    def initialize(sock)
      @io = sock
      @peeraddr = @io.peeraddr
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

#     def start
#       @import_thread = Thread.start {
# 	loop do
# 	  ev = import
# 	  @session.receive_event ev
# 	end
#       }

#       @export_thread = Thread.start {
# 	loop do
# 	  ev = @session.accepted_event
# 	  export(ev)
# 	end
#       }
#     end

    def event2packet_id(ev)
      unless id = Class2PacketId[ev.class]
	raise "#{ev.class}がPort::Class2PacketIdに登録されていません"
      end
      id
    end

    def import
      pid, sz = read(PACK_n_SIZE + PACK_N_SIZE).unpack("nN")
      t = PacketId2Class[pid]
      bin = read(sz).unpack("a#{sz}")
      a = Marshal.load(bin.first)
#puts "DUMP: #{a.inspect}"
      ev = Event.materialize(@session, t, *a)
puts "IMPORT: #{ev.inspect}"
      ev
    end

    def export(ev)
#       if ev.kind_of?(Event::Reply)
# 	puts "EXPORT0: #{ev.class} seq=#{ev.seq} result=#{ev.result.instance_eval{self.class}}"
#       end
puts "EXPORT: #{ev.inspect}"
#puts "SEL: #{ev.serialize.inspect}"
      id = event2packet_id(ev)
      ev.serialize
      s = Marshal.dump(ev.serialize)
      packet = [id, s.size, s].pack("nNa#{s.size}")
      @io.write(packet)
    end

    def read(n)
      begin
	packet = @io.read(n)
	fail EOFError, "socket closed" unless packet
	Fail ProtocolError unless packet.size == n
	packet
      rescue Errno::ECONNRESET
	puts "WARN: read中に[#{peeraddr.join(', ')}]の接続が切れました"
	raise DisconnectClient, peeraddr
      end
    end
    
    def write(packet)
      begin
	@io.write(packet)
      rescue Errno::ECONNRESET
	puts "WARN: write中に[#{peeraddr.join(', ')}]の接続が切れました"
	raise DisconnectClient, peeraddr
      end
    end
  end
end

