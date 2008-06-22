#!/usr/local/bin/ruby
#
#   port.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Nihon Rational Software Co.,Ltd)
#
# --
#
#   
#

require "thread"

require "dist/event"

# protocols:
# [packet_id, len, serialized_ev]

module DIST
  class Port

    PacketId2Class = [Event, Request, IteratorRequest, Reply, IteratorReply]
    Class2PacketId = {}
    Packets.each_with_index do
      |p, idx|
      Class2PacketId[p] = idx
    end

    PACK_n_SIZE = [1].pack("n").size
    PACK_N_SIZE = [1].pack("N").size

    def initialize(sm)
      @sm = sm
      @io = nil
    end

    def bind(io)
      @io = io
    end

    def import
      pid, sz = @io.read(PACK_n_SIZE + PACK_N_SIZE).unpck("nN")
      t = PacketIs2Class[pid]
      a = Marshal.load(@io.read(sz).unpack("a#{sz}"))
      Event.materialize(@sm, t, *a)
    end

    def export(ev)
      s = Marshal.dump(ev.serialize(@sm))
      @io.write([Class2PacketId[ev.type], s.size, s].pack("nNa#{s.size}")
    end
  end
end
