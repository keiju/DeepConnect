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

#    SESSION_SERVICE_NAME = "DC::SESSION"
    
    def initialize(deep_space, port, local_id = nil)
      @status = :INITIALIZE

      @organizer = deep_space.organizer
      @deep_space = deep_space
      @port = port
#puts "local_id=#{local_id}"      

      @export_queue = Queue.new
#      @import_queue = Queue.new
      @waiting = Hash.new
      @waiting_mutex = Mutex.new

      @iterator_event_queues = {}
      
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
	    @organizer.disconnect_deep_space(@deep_space, :SESSION_CLOSED)
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
	      @port.export(ev)
	    rescue Errno::EPIPE, DC::DisconnectClient
	      # EPIPE: クライアントが終了している
	      # DisconnectClient: 通信中にクライアント接続が切れた
	      @organizer.disconnect_deep_space(@deep_space, :SESSION_CLOSED)
	    end
	  else
	    puts "INFO: service is stoped, export event abandoned(#{ev.inspect})" 
	  end
	end
      }
      self
    end

    def stop_service(*opts)
      puts "INFO: STOP_SERVICE: Session: #{self.peer_uuid} #{opts.join(' ')} "
      @status = :SERVICE_STOP
      
      if !opts.include?(:SESSION_CLOSED)
	@port.shutdown_reading
      end
      @import_thread.exit
      @export_thread.exit
      
      waiting_events = @waiting.sort{|s1, s2| s1[0] <=> s2[0]}
      for seq, ev in waiting_events
	begin
	  DC.Raise SessionServiceStopped
	rescue
	  ev.result ev.reply(nil, $!)
	end
      end
      @waiting = nil
    end

    def stop(*opts)
      @port.close
    end

    # peerからの受取り
    def receive(ev)
      if ev.request?
	Thread.start do
	  case ev
	  when Event::IteratorCallBackRequest
	    req = nil
	    @waiting_mutex.synchronize do
	      req = @waiting[ev.seq[1]]
	    end
	    req.push_call_back ev
 	  when Event::IteratorRequest
 	    @iterator_event_queues[ev.seq] = Queue.new
 	    @organizer.evaluator.evaluate_iterator_request(self, ev)
	  else
	    @organizer.evaluator.evaluate_request(self, ev)
	  end
	end
      else
	case ev
	when Event::IteratorCallBackReply
	  req = nil
	  @waiting_mutex.synchronize do
	    req = @waiting[ev.seq]
	  end
	  @iterator_event_queues[ev.seq[1]].push ev
	else
	  req = nil
	  @waiting_mutex.synchronize do
	    req = @waiting.delete(ev.seq)
	  end
	  unless req
	    DC.InternalError "対応する request eventがありません(#{ev.inspect})"
	  end
	  req.result ev
	end
      end
    end

    def iterator_event_pop(itr_id)
      @iterator_event_queues[itr_id].pop
    end

    def iterator_exit(itr_id)
      @iterator_event_queues.delete(itr_id)
    end

    # イベントの受け取り
    def accept(ev)
      @export_queue.push ev
    end

    # イベントの生成/送信
    def send_to(ref, method, *args, &block)
      unless @status == :SERVICING
	DC.Raise SessionServiceStopped
      end
      if iterator?
	ev = Event::IteratorRequest.request(self, ref, method, *args)
	@waiting_mutex.synchronize do
	  @waiting[ev.seq] = ev
	end
	@export_queue.push ev
	ev.call_back do |callback_ev|
	  reply = nil
	  exit = true
	  begin
#puts "SEND_TO: #{callback_ev.args.inspect}"
	    if block.arity == 1 && callback_ev.args.size > 1
	      ret = yield callback_ev.args	      
	    else
	      ret = yield *callback_ev.args
	    end
	    exit = false
	    reply = callback_ev.reply(ret)
	  rescue
	    reply = callback_ev.reply(ret, $!, Event::IteratorCallBackReplyBreak)
	    raise
	  ensure
	    # break処理
	    # このメソッドから抜け出てしまう.
	    if exit
	      unless reply
		reply = callback_ev.reply(ret, nil, 
					  Event::IteratorCallBackReplyBreak)
	      end
	      @waiting.delete(ev.seq)
	    else
	      reply = callback_ev.reply(ret)
	    end
	    # 例外して即exit時の例外の伝搬が行われない
	    @export_queue.push reply
	  end
	end
	ev.result
      else
	ev = Event::Request.request(self, ref, method, *args)
	@waiting_mutex.synchronize do
	  @waiting[ev.seq] = ev
	end
	@export_queue.push ev
	ev.result
      end
    end

    # イベントID取得
    def next_request_event_id
      @next_request_event_id_mutex.synchronize do
	@next_request_event_id += 1
      end
    end

    def send_peer_session(req, *args)
      ev = Event::SessionRequest.request(self, (req.id2name+"_impl").intern, *args)
      @waiting_mutex.synchronize do
	@waiting[ev.seq] = ev
      end
      @export_queue.push ev
      ev.result
    end

    def send_peer_session_no_recv(req, *args)
      ev = Event::SessionRequestNoReply.request(self, (req.id2name+"_impl").intern, *args)
      @export_queue.push ev
    end

    def send_disconnect
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
      send_peer_session(:register_root, id)
      nil
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
      if now > @last_keep_alive + KEEP_ALIVE_INTERVAL*2
	puts "KEEP ALIVE: session #{self} is dead." if DISPLAY_KEEP_ALIVE
	false
      else
	puts "KEEP ALIVE: send #{self} to keep alive." if DISPLAY_KEEP_ALIVE
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

