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
require "monitor"
require "weakref"

require "ipaddr"

module DeepConnect
  class Session

#    SESSION_SERVICE_NAME = "DeepConnect::SESSION"

    def initialize(deep_space, port, local_id = nil)
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
    end

    attr_reader :organizer
    attr_reader :deep_space

    def peer_uuid
      @deep_space.peer_uuid
    end
    alias peer_id peer_uuid

    def start
      send_prototype

      @import_thread = Thread.start {
	loop do
	  begin
	    ev = @port.import
	  rescue EOFError, Port::DisconnectClient
	    # EOFError: クライアントが閉じていた場合
	    # DisconnectClient: 通信中にクライアント接続が切れた
	    stop
	  rescue Port::ProtocolError
	    # 何らかの障害のためにプロトコルが正常じゃなくなった
	  end
	  receive(ev)
	end
      }

      @export_thread = Thread.start {
	loop do
	  ev = @export_queue.pop
	  begin
	    @port.export(ev)
	  rescue Errno::EPIPE, Port::DisconnectClient
	    # EPIPE: クライアントが終了している
	    # DisconnectClient: 通信中にクライアント接続が切れた
	    stop
	  end
	end
      }
      self
    end

    def stop
      @import_thread.exit
      @export_thread.exit
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
	    

# 	    @iterator_event_queues[ev.itr_id].push ev
	    
	    # when ItratorAbort
# さあどうするか?
# 	  when Event::IteratorNextRequest
# #             , Event::IteratorRetryRequest
# 	    @iterator_event_queues[ev.itr_id].push ev
# 	  when Event::IteratorExitRequest
# 	    @iterator_event_queues[ev.itr_id].push ev
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
	    raise "対応する request eventがありません(#{ev.inspect})"
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
    def send_to(ref, method, *args)
      if iterator?
	ev = Event::IteratorRequest.request(self, ref, method, *args)
	@waiting_mutex.synchronize do
	  @waiting[ev.seq] = ev
	end
	@export_queue.push ev
	ev.call_back do |callback_ev|
	  call_back_reply = nil
	  exit = true
	  begin
	    ret = yield *callback_ev.args
	    exit = false
	    reply = callback_ev.reply(ret)
	  rescue
	    reply = callback_ev.reply(ret, $!)
	  ensure
	    # break処理
	    # このメソッドから抜け出てしまう.
	    if exit
	      reply = callback_ev.reply(ret, nil, 
					Event::IteratorCallBackReplyBreak)
	      @waiting.delete(ev.seq)
	    else
	      reply = callback_ev.reply(ret)
	    end
	  end
	  @export_queue.push reply
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

    def get_service(name)
      send_peer_session(:get_service, name)
    end

    def get_service_impl(name)
      if sv = @organizer.service(name)
	puts "INFO: get_service: #{name}, #{sv}"
      else
	puts "WARN: service Not Found: #{name}"
      end
      sv
    end

    def register_root_to_peer(id)
      send_peer_session(:register_root, id)
      nil
    end

    def register_root_impl(id)
      @deep_space.register_root_from_other_session(id)
    end

    def deregister_root_to_peer(id)
      send_peer_session_no_recv(:deregister_root, id)
    end

    def deregister_root_impl(id)
      @deep_space.delete_root(id)
      nil
    end

    def send_prototype
      specs_dump = Marshal.dump(Organizer::method_specs)
      send_peer_session_no_recv(:recv_prototype, specs_dump)
    end

    def recv_prototype_impl(specs_dump)
      specs = Marshal.load(specs_dump)
      @deep_space.set_method_specs(specs)
    end
  end
end

