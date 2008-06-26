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
require "mutex_m"
require "monitor"

require "ipaddr"

module DeepConnect
  class Session

#    SESSION_SERVICE_NAME = "DeepConnect::SESSION"

    def initialize(org, port, local_id = nil)
      @organizer = org
      @port = port
#puts "local_id=#{local_id}"      
      unless local_id
	local_id = @port.peeraddr[1]
      end

      addr = @port.peeraddr[3]
      ipaddr = IPAddr.new(addr)
      ipaddr = ipaddr.ipv4_mapped if ipaddr.ipv4?
      @peer_uuid = [ipaddr.to_s, local_id]

      @export_queue = Queue.new
      @import_queue = Queue.new
      @waiting = Hash.new
      @waiting.extend Mutex_m

      @iterator_event_queues = {}
      
      @roots = Hash.new

      @next_request_event_id = 0
      @next_request_event_id_mutex = Mutex.new
    end

    attr_reader :organizer

    attr_reader :peer_uuid
    alias peer_id peer_uuid

    def start
#      @organizer.register_service(SESSION_SERVOCE_NAME, self)

      @import_thread = Thread.start {
	loop do
	  begin
	    ev = @port.import
	  rescue EOFError
	    # クライアントが閉じていた場合
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
	  rescue Errno::EPIPE
	    # クライアントが終了している
	    stop
	  end
	end
      }

      self
    end

    def stop
      Thread.start {
	@import_thread.exit
	@export_thread.exit
      }
    end

    # peerからの受取り
    def receive(ev)
      if ev.request?
	Thread.start do
	  case ev
	    # when ItratorAbort
	  when Event::IteratorNextRequest
#             , Event::IteratorRetryRequest
	    @iterator_event_queues[ev.itr_id].push ev
	  when Event::IteratorExitRequest
	    @iterator_event_queues[ev.itr_id].push ev
	  when Event::IteratorRequest
	    @iterator_event_queues[ev.seq] = Queue.new
	    @organizer.evaluator.evaluate_iterator_request(self, ev)
	  else
	    @organizer.evaluator.evaluate_request(self, ev)
	  end
	end
      else
	req = nil
	@waiting.synchronize do
	  if ev.iterator?
	    if ev.finish?
	      req = @waiting.delete(ev.seq)
	    else
	      req = @waiting[ev.seq]
	    end
	  else
#puts "WAITING: #{@waiting.inspect}"
	    req = @waiting.delete(ev.seq)
	  end
	end
	req.result ev
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
#      loop do
      @export_queue.push ev
#      end
    end

    # イベントの生成/送信
    def send_to(ref, method, *args)
      if iterator?
	ev = Event::IteratorRequest.request(self, ref, method, *args)
	@waiting.synchronize do
	  @waiting[ev.seq] = ev
	end
	@export_queue.push ev
	ev.results do |elm|
	  begin
	    exit = true
	    yield elm
	    exit = false
	  ensure
	    if exit
	      next_ev = Event::IteratorExitRequest.request(self, ref, method, ev.seq)
	      next_ev.set_seq(ev.seq)
	      @export_queue.push next_ev
	    end
	  end
	  next_ev = Event::IteratorNextRequest.request(self, ref, method, ev.seq)
	  next_ev.set_seq(ev.seq)
	  @export_queue.push next_ev
	end
      else
	ev = Event::Request.request(self, ref, method, *args)
	@waiting.synchronize do
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

    def set_root(root)
      @roots[root.object_id] = root
      root.object_id
    end
    
    def root(id)
      @roots[id]
    end

#     def universal_id
#       addr, port = @port.addr.values_at(3,1)
#       ipaddr = IPAddr.new(addr)
#       ipaddr = ipaddr.ipv4_mapped if ipaddr.ipv4?
#       return ipaddr.to_s, port
#     end

#     # peer情報
#     def peer_universal_id
#       addr, port = @port.peeraddr.values_at(3,1)
#       ipaddr = IPAddr.new(addr)
#       ipaddr = ipaddr.ipv4_mapped if ipaddr.ipv4?
#       return ipaddr.to_s, port
#     end
#     alias peer_id peer_universal_id

    def send_peer_session(req, *args)
      ev = Event::SessionRequest.request(self, (req.id2name+"_impl").intern, *args)
	@waiting.synchronize do
	  @waiting[ev.seq] = ev
	end
      @export_queue.push ev
      ev.result
    end

    def get_service(name)
      send_peer_session(:get_service, name)
    end

    def get_service_impl(name)
      @organizer.service(name)
    end

  end
end

