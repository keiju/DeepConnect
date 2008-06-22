#!/usr/local/bin/ruby
#
#   proxy.rb - 
#   	$Release Version: $
#   	$Revision: 1.2 $
#   	$Date: 91/04/20 17:24:57 $
#   	by Keiju ISHITSUKA(SHL Japan Inc.)
#
# --
#
#   
#
$stdout.sync = 1
$\ = "\n"

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

class ServiceManager
  def send_to(peer, method, *args)
    pxargs = args.collect{|elm| Proxy(self, elm)}
    if iterator?
      itr = proc
      return recv_each(peer, method, itr, *pxargs)
    else
      return recv_from(peer, method, *pxargs)
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

class Foo
  def foo(x, y)
    return x + y
  end
end

$SM = ServiceManager.new

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
  print px.inspect
  for e in px
    print e.inspect
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
  print px + py
  print 1 + px
  print 0/px
end

eval "test_"+ARGV[0]
