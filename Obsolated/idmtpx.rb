#!/usr/local/bin/ruby
#
#   idmtpx.rb - 
#   	$Release Version: $
#   	$Revision: 1.2 $
#   	$Date: 97/02/14 15:26:45 $
#   	by Keiju ISHITSUKA(SHL Japan Inc.)
#
# --
#
#   
#

$:.unshift ENV["HOME"]+"/ruby"

Thread.abort_on_exception = TRUE

require "thread.rb"
require "mutex_m.rb"

class PxEvent
  
  def PxEvent.materialize(sm, type, *rest)
    type.send("materialize_sub", sm, type, *rest)
  end

  def initialize(receiver)
    @receiver = receiver
  end
  
  attr :receiver
  attr :seq
  
  public :iterator?
end

class PxEventRequest < PxEvent
  SEQ = [0]
  
  def PxEventRequest.request(receiver, method, *args)
    req = new(receiver, method, *args)
    req.init_req
    req
  end

  def PxEventRequest.receipt(seq, receiver, method, *args)
    rec = new(receiver, method, *args)
    rec.set_seq(seq)
    rec
  end
  
  def PxEventRequest.materialize_sub(sm, type, seq, receiver, method, *args)
    type.receipt(seq,
		 sm.root(receiver),
		 method,
		 *args.collect{|elm| Proxy.materialize(sm, *elm)})
  end
  
  def initialize(receiver, method, *args)
    super(receiver)
    @method = method
    @args = args
  end
  
  def init_req
    @seq = SEQ[0] += 1
    @results = Queue.new
  end
  
  def set_seq(seq)
    @seq = seq
  end
  
  def apply_on(sm)
    Thread.start do
      print "apply_on: ", self.inspect, "\n"
      ret = @receiver.send(@method, *@args)
      sm.req PxEventReply.new(@seq, @receiver, ret).serialize(sm)
    end
  end
  
  def serialize(sm)
    [type, @seq, @receiver.peer_id, @method].concat(@args)
  end
  
  def request?
    TRUE
  end
  
  def iterator?
    FALSE
  end
  
  def result(*ret)
    if ret.size == 0
      @results.pop
    else
      @results.push *ret
    end
  end
  
  attr :method
  attr :args
end

class PxEventIteratorRequest < PxEventRequest
  def apply_on(sm)
    Thread.start do
#      print "apply_on: ", self.inspect
      @receiver.send(@method, *@args) do
	|ret|
	sm.req PxEventIteratorReply.new(@seq, @receiver, ret).serialize(sm)
      end
      sm.req PxEventIteratorReply.new(@seq, @receiver, :finish).serialize(sm)
    end
  end
  
  def iterator?
    TRUE
  end
  
  def results(*ret)
    if ret.empty?
      while (ret = @results.pop) != :finish
	yield ret
      end
    else
      @results.push *ret
    end
  end
end

class PxEventReply < PxEvent
  def PxEventReply.materialize_sub(sm, type, seq, receiver, ret)
    type.new(seq, sm.root(receiver), Proxy.materialize(sm, *ret))
  end
  
  def initialize(seq, receiver, ret)
    super(receiver)
    @seq = seq
    @result = ret
  end
  
  def serialize(sm)
    [type, @seq, Proxy.serialize(sm, @receiver), Proxy.serialize(sm, @result)]
  end
  
  def request?
    FALSE
  end
  
  def iterator?
    FALSE
  end
  
  attr :result
end

class PxEventIteratorReply < PxEventReply
  def iterator?
    TRUE
  end
  
  def finish?
    @result == :finish
  end
end

class ServiceManager
  def ServiceManager.start(name)
    sm = new(name)
    sm.start
  end
  
  def start
    @exporter = Thread.start{self.accept}
    @importer = Thread.start{self.reply}
    self
  end
  
  def accept
    loop do
      ev = @export_queue.pop
      print "Accept(#{@name})"  if $SYM
#      print ev.inspect
      if ev.kind_of? PxEvent
	@waiting.synchronize do
	  @waiting[ev.seq] = ev
	end
	@peer.recv(ev.serialize(self))
      else
	@peer.recv(ev)
      end
    end
  end
  
  def reply
    loop do
      ev = @import_queue.pop
#      print ev.join(" ")
      ev = PxEvent.materialize(self, *ev)
      print "Reply(#{@name})" if $SYM
      if ev.request?
	print "  Req" if $SYM
	ev.apply_on(self)
      else
	print "  Rep" if $SYM
	req = nil
	@waiting.synchronize do
	  if ev.iterator?
	    if ev.finish?
	      req = @waiting.delete(ev.seq)
	    else
	      req = @waiting[ev.seq]
	    end
	  else
	    req = @waiting.delete(ev.seq)
	  end
	end
	req.result ev.result
      end
    end
  end
    
  def recv(ev)
    @import_queue.push(ev)
  end
  
  def req(ev)
    @export_queue.push(ev)
  end
  
  def initialize(name)
    @name = name
    @waiting = Hash.new
    @waiting.extend Mutex_m
    
    @export_queue = Queue.new
    @import_queue = Queue.new
    
    @roots = Hash.new
  end
  
  attr :peer, TRUE
  
  def send_to(proxy, method, *args)
    pxargs = args.collect{|elm| Proxy.serialize(self, elm)}
    if iterator?
      ev = PxEventIteratorRequest.request(proxy, method, *pxargs)
      @export_queue.push ev
      ev.results do
	|elm|
	yield elm
      end
    else
      ev = PxEventRequest.request(proxy, method, *pxargs)
      @export_queue.push ev
      ev.result
    end
  end
  
  def set_root(root)
    @roots[root.id] = root
    root.id
  end
  
  def root(id)
    @roots[id]
  end
end


# sm.peer上のオブジェクトのプロキシを生成
def Proxy(sm, v)
  case v
  when Fixnum, TRUE, FALSE, nil
    v
  when Proxy
    if sm == v.service_manager
      v.peer
    else
      v
    end
  else
    Proxy.new(sm, v)
  end
end

class Proxy
  # sm ローカルなプロキシを生成
  #	[クラス名, 値]
  #	[クラス名, ローカルSM, 値]
  def Proxy.serialize(sm, value)
    if value.kind_of? Proxy
      [value.type, value.service_manager.peer, value.peer_id]
    else
      case value
      when Fixnum, TRUE, FALSE, nil
	[value.type, value]
      else
	id = sm.set_root(value)
	[Proxy, sm, id]
      end
    end
  end
  
  def Proxy.materialize(sm, type, *serial)
    if type == Proxy
      Proxy(sm, type.new(serial[0].peer, serial[1]))
    else
      serial[0]
    end
  end
  
  def Proxy.register(sm, o)
    sm.peer.set_root(o)
    Proxy.new(sm, o.id)
  end
  
  def initialize(sm, peer_id)
    @service_manager = sm
    @peer_id = peer_id
  end
  
  def service_manager
    @service_manager
  end
  
  def peer
    @service_manager.peer.root(@peer_id)
  end
  
  def peer_id
    @peer_id
  end
  
  def method_missing(method, *args)
    if iterator?
      @service_manager.send_to(self, method.id2name, *args) do
	|elm|
	yield elm
      end
    else
      @service_manager.send_to(self, method.id2name, *args)
    end
  end
  
  def to_s
    @service_manager.send_to(self, "to_s")
  end
  
  def to_a
    @service_manager.send_to(self, "to_a")
  end
  
  def coerce(other)
    return  other, peer
  end
  
  def inspect
    sprintf("<Proxy: SM=%s id=%d>", @service_manager.to_s, @peer_id) 
  end
end

#
# test program
#

def p(*o)
  if o.size == 1
    print o[0].inspect
  else
    print o[0], o[1].inspect
  end
end

$stdout.sync = 1
$\ = "\n"
$SYM = TRUE

class Foo
  def foo(x, y)
    r = x + y
    return r
  end
end

$SM_A = ServiceManager.start("A")
$SM_B = ServiceManager.start("B")
$SM_A.peer = $SM_B
$SM_B.peer = $SM_A

$SM = $SM_A

def test_1
  print "Case: 1"
  px = Proxy.register($SM, 2)
  print px + 1
end

def test_2
  print "Case: 2"
  px = Proxy.register($SM, Array.new)
  px[0] = 2
  px[1] = 3
  px[2] = 4
#  print px.inspect
  for e in px
    print "test_2: ", e.inspect
#    sleep 1
  end
end

def test_3
  print "Case: 3"
  px = Proxy.register($SM, Foo.new)
  print px.foo(1, 2).inspect
end

def test_4
  print "Case: 4"
  px = Proxy.register($SM, Foo.new)
  ret = px.foo("a", "b")
  p ret
end

def test_5
  print "Case: 5"
  px = Proxy.register($SM, Foo.new)
  ps1 = Proxy.register($SM, "aa")
  ps2 = Proxy.register($SM, "bb")
  print "ANS: ", (ps1 + "zz").inspect
  print "ANS: ", px.foo(ps1, ps2).inspect
#  print ps1.to_s
end

def test_6
  print "Case: 6"
  px = Proxy.register($SM, 1111111111111111111111111111111)
  py = Proxy.register($SM, 1111111111111122222222222222222)
  print (px + 1).inspect
  print (px + py).inspect
  print 1 + px
  print 0/px
end

def test_7
  print "Case: 7"
  px = Proxy.register($SM, ["a", "b", "c"])
  p "px: ", px
  p "px.peer: ", px.peer
  
  py = Proxy.register($SM, Array.new)
  for elm in px
    p "elm: ", elm
    py.push elm+"zz"
  end
  p "py: ", py
  p "py.peer", py.peer
end

def test_71
  print "Case: 71"
  px = Proxy.register($SM, [1, 2, 3])
  py = Proxy.register($SM, Array.new)
  for elm in px
    print "elm: ", elm
    py.push elm+1
  end
  print py.inspect
  print py.peer.inspect
end


def test_8
  
  print "Case: 8"
  $SYM = FALSE
  t2 = Thread.start {
    test_7
  }
  
  t1 = Thread.start {
    test_2
    test_2
    test_2
    test_2
    test_2
  }
  
  Thread.join t1
  Thread.join t2
  
#  sleep 10
  
end

def test_9
  print "Case: 9"
  px = Proxy.register($SM, open("/etc/printcap"))
  
  for l in px
    sleep 0.1
    print l
  end
end

eval "test_"+ARGV[0]

