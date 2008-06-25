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

    PacketId2Class = [
      Event::Event, 
      Event::Request, Event::IteratorRequest, Event::SessionRequest,
      Event::Reply, Event::IteratorReply, Event::IteratorReplyFinish, Event::SessionReply,
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
    end

    def addr
      @io.addr
    end

    def peeraddr
      @io.peeraddr
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
puts "EXPORT: #{ev.inspect}"
#puts "SEL: #{ev.serialize.inspect}"
      s = Marshal.dump(ev.serialize)
      @io.write([Class2PacketId[ev.class], s.size, s].pack("nNa#{s.size}"))
    end

    def read(n)
      packet = @io.read(n)
      fail EOFError, "socket closed" unless packet
      Fail ProtocolError unless packet.size == n
      packet
    end
  end
end

