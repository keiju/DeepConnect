# encoding: UTF-8
#
#   session.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

require "thread"
#require "mutex_m"
require "weakref"

require "ipaddr"

require "deep-connect/exceptions"

module DeepConnect
  class Session

    def initialize(deep_space, port, local_id = nil)
      @status = :INITIALIZE

      @organizer = deep_space.organizer
      @deep_space = deep_space
      @port = port

      @export_queue = Queue.new

      @waiting = Hash.new
      @waiting_mutex = Mutex.new
      @next_request_event_id = 0
      @next_request_event_id_mutex = Mutex.new

      @last_keep_alive = nil
    end

    attr_reader :organizer
    attr_reader :deep_space

    def peer_uuid
      @deep_space.peer_uuid
    end
    alias peer_id peer_uuid

    def start
      @last_keep_alive = @organizer.tick

      @status = :SERVICING
      send_class_specs

      @import_thread = Thread.start {
	loop do
	  begin
	    ev = @port.import
	    @last_keep_alive = @organizer.tick
	  rescue EOFError, DC::DisconnectClient
	    # EOFError: クライアントが閉じていた場合
	    # DisconnectClient: 通信中にクライアント接続が切れた
	    Thread.start do
	      @organizer.disconnect_deep_space(@deep_space, :SESSION_CLOSED)
	    end
	    Thread.stop
	  rescue DC::ProtocolError
	    # 何らかの障害のためにプロトコルが正常じゃなくなった
	  end
	  if @status == :SERVICING
	    receive(ev)
	  else
	    puts "INFO: service is stoped, imported event abandoned(#{ev.inspect})" 
	  end
	end
      }

      @export_thread = Thread.start {
	loop do
	  ev = @export_queue.pop
	  if @status == :SERVICING
	    begin
	      # export中にexportが発生するとデッドロックになる
	      # threadが欲しいか?
#	      Thread.start do
		@port.export(ev)
#	      end
	    rescue Errno::EPIPE, DC::DisconnectClient
	      # EPIPE: クライアントが終了している
	      # DisconnectClient: 通信中にクライアント接続が切れた
	      Thread.start do
		@organizer.disconnect_deep_space(@deep_space, :SESSION_CLOSED)
	      end
	      Thread.stop
	    end
	  else
	    puts "INFO: service is stoped, export event abandoned(#{ev.inspect})" 
	  end
	end
      }
      self
    end

    def stop_service(*opts)
      unless DISABLE_INFO
	puts "INFO: STOP_SERVICE: Session: #{self.peer_uuid} #{opts.join(' ')} "
      end
      org_status = @status
      @status = :SERVICE_STOP
      
      if !opts.include?(:SESSION_CLOSED)
	@port.shutdown_reading
      end

      if org_status == :SERVICING
	@import_thread.exit
	@export_thread.exit
      
	@waiting_mutex.synchronize do
	  waiting_events = @waiting.sort{|s1, s2| s1[0] <=> s2[0]}
	  for seq, ev in waiting_events
	    begin
	      p ev
	      DC.Raise SessionServiceStopped
	    rescue
	      ev.result = ev.reply(nil, $!)
	    end
	  end
	  @waiting.clear
	end
      end

    end

    def stop(*opts)
      begin
	@port.close
      rescue IOError
	puts "WARN: #{$!}"
      end
    end

    # peerからの受取り
    def receive(ev)
      #Thread.start do
      if ev.request?
	Thread.start do
	  case ev
 	  when Event::IteratorCallBackRequest
	    @organizer.evaluator.evaluate_block_yield(self, ev)
 	  when Event::IteratorRequest
 	    @organizer.evaluator.evaluate_iterator_request(self, ev)
	  else
	    @organizer.evaluator.evaluate_request(self, ev)
	  end
	end
      else
	req = nil
	@waiting_mutex.synchronize do
	  req = @waiting.delete(ev.seq)
	end
	unless req
	  DC.InternalError "対応する request eventがありません(#{ev.inspect})"
	end
	req.result = ev
      end
      #end
    end

    # イベントの受け取り
    def accept(ev)
      @export_queue.push ev
    end

    # イベントの生成/送信
    def send_to(ref, method, args=[], &block)
      unless @status == :SERVICING
	DC.Raise SessionServiceStopped
      end
      if iterator?
	ev = Event::IteratorRequest.request(self, ref, method, args, block)
      else
	ev = Event::Request.request(self, ref, method, args)
      end
      @waiting_mutex.synchronize do
	@waiting[ev.seq] = ev
      end
      @export_queue.push ev
      ev.result
    end

    def block_yield(event, args)
      ev = Event::IteratorCallBackRequest.call_back_event(event, args)
      @waiting_mutex.synchronize do
	@waiting[ev.seq] = ev
      end
      @export_queue.push ev
      ev
    end

    # イベントID取得
    def next_request_event_id
      @next_request_event_id_mutex.synchronize do
	@next_request_event_id += 1
      end
    end

    def send_peer_session(req, *args)
      ev = Event::SessionRequest.request(self, (req.id2name+"_impl").intern, args)
      @waiting_mutex.synchronize do
	@waiting[ev.seq] = ev
      end
      @export_queue.push ev
      ev.result
    end

    def send_peer_session_no_recv(req, *args)
      ev = Event::SessionRequestNoReply.request(self, (req.id2name+"_impl").intern, args)
      @export_queue.push ev
    end

    def send_disconnect
      return unless  @status == :SERVICING

      ev = Event::SessionRequestNoReply.request(self, :recv_disconnect)
      @port.export(ev)
    end

    def recv_disconnect
      @organizer.disconnect_deep_space(@deep_space, :REQUEST_FROM_PEER)
    end
    Organizer.def_interface(self, :recv_disconnect)


    def get_service(name)
      if (sv = send_peer_session(:get_service, name)) == :DEEPCONNECT_NO_SUCH_SERVICE
	DC.Raise NoServiceError, name
      end
      sv
    end

    def get_service_impl(name)
      @organizer.service(name)
    end
    Organizer.def_interface(self, :get_service_impl)

    def register_root_to_peer(id)
      # 同期を取るためにno_recvはNG
      send_peer_session(:register_root, id)
    end

    def register_root_impl(id)
      @deep_space.register_root_from_other_session(id)
    end
    Organizer.def_interface(self, :register_root_impl)

    def deregister_root_to_peer(ids)
      idsdump = Marshal.dump(ids)
      send_peer_session_no_recv(:deregister_root, idsdump)
    end

    def deregister_root_impl(idsdump)
      ids = Marshal.load(idsdump)
      @deep_space.delete_roots(ids)
      nil
    end
    Organizer.def_interface(self, :deregister_root_impl)

    def send_class_specs
      specs_dump = Marshal.dump(Organizer::class_specs)
      send_peer_session_no_recv(:recv_class_specs, specs_dump)
    end

    def recv_class_specs_impl(specs_dump)
      specs = Marshal.load(specs_dump)
      @deep_space.class_specs = specs
#p specs
    end
    Organizer.def_interface(self, :recv_class_specs_impl)


#     def send_class_specs(cspecs)
#       specs_dump = Marshal.dump(cspecs)
#       ret = send_peer_session(:send_class_specs_impl, cspecs)
#     end

#     def send_class_specs_impl(spec_dump)
#       specs = Marshal.load(spec_dump)
#       @object_space.recv_class_specs(specs)
#     end

    def keep_alive
      now = @organizer.tick
      if now > @last_keep_alive + KEEP_ALIVE_INTERVAL*10
	puts "KEEP ALIVE: session #{self} is dead." if DISPLAY_KEEP_ALIVE
	false
      else
	if DISPLAY_KEEP_ALIVE
	  puts "KEEP ALIVE: session #{self} is alive(INT: #{now - @last_keep_alive})."
	  puts "KEEP ALIVE: send #{self} to keep alive."
	end
	send_peer_session_no_recv(:recv_keep_alive)
	true
      end
    end

    def recv_keep_alive_impl
      puts "RECV_KEEP_ALIVE"  if DISPLAY_KEEP_ALIVE
      @last_keep_alive = @organizer.tick
    end
    Organizer.def_interface(self, :recv_keep_alive_impl)
  end
end

