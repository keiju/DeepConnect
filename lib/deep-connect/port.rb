# encoding: UTF-8
#
#   port.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
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

    def import2
#      puts "IMPORT: start0" 
#      sz = read(PACK_N_SIZE).unpack("N").first
#      bin = read(sz)
      a = Marshal.load(@io)
      begin
	# ĳĳć, ōŃňů|ůČ??8Ĺī??-ĢĪ.
	ev = Event.materialize(@session, a.first, *a)
      rescue
	p $!, $@
	raise
      end
      puts "IMPORT: #{ev.inspect}" if Conf.MESSAGE_DISPLAY
      ev
    end

    def import
#      puts "IMPORT: start0" 
      sz = read(PACK_N_SIZE).unpack("N").first
      bin = read(sz)
      begin
	a = Marshal.load(bin)
      rescue
	p bin
	p $!, $@
	raise
      end
      begin
	# ここで, ネットワーク通信発生する可能性あり.
	ev = Event.materialize(@session, a.first, *a)
      rescue
	p $!, $@
	raise
      end
      puts "IMPORT: #{ev.inspect}" if Conf.MESSAGE_DISPLAY
      ev
    end

    def export2(ev)
      puts "EXPORT: #{ev.inspect}" if Conf.MESSAGE_DISPLAY
      bin = Marshal.dump(ev.serialize, @io)
#      size = bin.size

#      packet = [size].pack("N")+bin
#      write(packet)
      puts "EXPORT: finsh" if Conf.MESSAGE_DISPLAY
    end

    def export(ev)
      puts "EXPORT: #{ev.inspect}" if Conf.MESSAGE_DISPLAY
      begin
	bin = Marshal.dump(ev.serialize)
      rescue
	puts "Exception Rised: #{$!}"
	puts $@
	p ev.serialize
	raise
      end
      size = bin.size

      packet = [size].pack("N")+bin
      write(packet)
      puts "EXPORT: finsh" if Conf.MESSAGE_DISPLAY
    end

#     def import
#       sz = read(PACK_N_SIZE).unpack("N").first
#       bin = read(sz).unpack("a#{sz}")
#       a = Marshal.load(bin.first)
#       ev = Event.materialize(@session, a.first, *a)
#       puts "IMPORT: #{ev.inspect}" if Conf.MESSAGE_DISPLAY
#       ev
#     end

#     def export(ev)
#       puts "EXPORT: #{ev.inspect}" if Conf.MESSAGE_DISPLAY
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
      rescue Errno::ECONNRESET, EOFError
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

