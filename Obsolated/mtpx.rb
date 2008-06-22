#!/usr/local/bin/ruby
#
#   mtpx.rb - 
#   	$Release Version: $
#   	$Revision: 1.2 $
#   	$Date: 97/02/06 12:53:55 $
#   	by Keiju ISHITSUKA(SHL Japan Inc.)
#
# --
#
#   
#

$:.unshift ENV["HOME"]+"/ruby"

$stdout.sync = 1
$\ = "\n"



$SYM = TRUE

require "thread.rb"
require "mutex_m.rb"

class PxEvent
  def initialize(peer)
    @peer = peer
  end
  
  attr :peer
  attr :seq
  
  public :iterator?
end

class PxEventRequest < PxEvent
  SEQ = [0]
  def initialize(peer, method, *args)
    super(peer)
    @seq = SEQ[0] += 1
    @method = method
    @args = args
    @results = Queue.new
  end
  
  def apply_to(sm)
    ret = @peer.send(@method, *@args)
    sm.req PxEventReply.new(@peer, @seq, Proxy(sm.peer, ret)) 
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
  def apply_to(sm)
    @peer.send(@method, *@args) do
      |ret|
      sm.req PxEventIteratorReply.new(@peer, @seq, Proxy(sm.peer, ret))
    end
    sm.req PxEventIteratorReply.new(@peer, @seq, :finish)
  end
  
  def iterator?
    TRUE
  end
  
  def result(*ret)
    if ret.size == 0
      while (ret = @results.pop) != :finish
	yield ret
      end
    else
      @results.push *ret
    end
  end
end

class PxEventReply < PxEvent
  def initialize(peer, seq, ret)
    super(peer)
    @seq = seq
    @result = ret
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
      @waiting.synchronize do
	@waiting[ev.seq] = ev
      end
      @peer.recv(ev)
    end
  end
  
  def reply
    loop do
      ev = @import_queue.pop
      print "Reply(#{@name})" if $SYM
      if ev.request?
	print "  Req" if $SYM
	Thread.start do
#	  ev.apply_to(@peer)
	  ev.apply_to(self)
	end
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
  end
  
  attr :peer, TRUE
  
  def send_to(peer, method, *args)
    pxargs = args.collect{|elm| Proxy(self, elm)}
    if iterator?
      ev = PxEventIteratorRequest.new(peer, method, *pxargs)
      @export_queue.push ev
      ev.result do
	|elm|
	yield elm
      end
    else
      ev = PxEventRequest.new(peer, method, *pxargs)
      @export_queue.push ev
      ev.result
    end
  end
  
  def recv_from(peer, method, *pxargs)
#    printf "recv_from(%s, %s, %s)", peer.inspect, method, pxargs.inspect
    ret = peer.send(method, *pxargs)
    return Proxy(self, ret)
  end
  
  def recv_each(peer, method, itr, *pxargs)
    print peer.inspect
    print method.inspect
    print itr.inspect
    print pxargs.inspect
    peer.send(method, *pxargs) do
      |elm|
      Proxy(self, itr.call(elm))
    end
  end
  
end

def Proxy(sm, v)
  case v.type
  when "Fixnum", "TRUE", "FALSE", "Nil"
    v
  when "Proxy"
    if sm == v.service_manager
      v.peer
    else
      Proxy.new(sm, v.peer)
    end
  else
    Proxy.new(sm, v)
  end
end

class Proxy
  def initialize(sm, peer)
    @service_manager = sm
    @peer = peer
  end
  
  def service_manager
    @service_manager
  end
  
  def peer
    @peer
  end
  
  def method_missing(method, *args)
    if iterator?
      @service_manager.send_to(@peer, method, *args) do
	|elm|
	yield elm
      end
    else
      @service_manager.send_to(@peer, method, *args)
    end
  end
  
  def to_s
#    print "to_s: @peer = ", @peer.inspect
    @service_manager.send_to(@peer, "to_s").peer
  end
  
  def to_a
    @service_manager.send_to(@peer, "to_a").peer
  end
  
  def coerce(other)
    return  other, @peer
  end
  
end

#
# test program
#
class Foo
  def foo(x, y)
    return x + y
  end
end

$SM_A = ServiceManager.start("A")
$SM_B = ServiceManager.start("B")
$SM_A.peer = $SM_B
$SM_B.peer = $SM_A

$SM = $SM_A

def test_1
  print "Case: 1"
  px = Proxy.new($SM, 1)
  print px + 1
end

def test_2
  print "Case: 2"
  px = Proxy.new($SM, Array.new)
  px[0] = 2
  px[1] = 3
  px[2] = 4
#  print px.inspect
  for e in px
    print e.inspect
#    sleep 1
  end
end

def test_3
  print "Case: 3"
  px = Proxy.new($SM, Foo.new)
  print px.foo(1, 2).inspect
end

def test_4
  print "Case: 4"
  px = Proxy.new($SM, Foo.new)
  print px.foo("a", "b").inspect
end

def test_5
  print "Case: 5"
  px = Proxy.new($SM, Foo.new)
  ps1 = Proxy($SM, "aa")
  ps2 = Proxy($SM, "bb")
  print px.foo(ps1, ps2).inspect
  print (ps1 + "zz").inspect
  print ps1.to_s
end

def test_6
  print "Case: 6"
  px = Proxy.new($SM, 1111111111111111111111111111111)
  py = Proxy.new($SM, 1111111111111122222222222222222)
  print (px + 1).inspect
  print (px + py).inspect
  print 1 + px
  print 0/px
end

def test_7
  print "Case: 7"
  px = Proxy.new($SM, ["a", "b", "c"])
  py = Proxy.new($SM, Array.new)
  for elm in px
    py.push elm+"zz"
  end
  print py.inspect
end

def test_8
  print "Case: 8"
  $SYM = FALSE
  Thread.start do
    test_7
  end
  
  Thread.start do
    test_2
    test_2
    test_2
    test_2
    test_2
  end
  
  sleep 10
  
end

eval "test_"+ARGV[0]

