#!/usr/local/bin/ruby
#
#   test.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Nihon Rational Software Co.,Ltd)
#
# --
#
#   
#

$:.unshift ENV["HOME"]+"/ruby"
$:.unshift ".."

require "dist.rb"
include DIST


Thread.abort_on_exception = TRUE


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

$SM_A = Controller.start("A")
$SM_B = Controller.start("B")
$SM_A.peer = $SM_B
$SM_B.peer = $SM_A

$SM = $SM_A

def test_1
  print "Case: 1"
  px = Reference.register($SM, 2)
  print px + 1
end

def test_2
  print "Case: 2"
  px = Reference.register($SM, Array.new)
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
  px = Reference.register($SM, Foo.new)
  print px.foo(1, 2).inspect
end

def test_4
  print "Case: 4"
  px = Reference.register($SM, Foo.new)
  ret = px.foo("a", "b")
  p ret
end

def test_5
  print "Case: 5"
  px = Reference.register($SM, Foo.new)
  ps1 = Reference.register($SM, "aa")
  ps2 = Reference.register($SM, "bb")
  print "ANS: ", (ps1 + "zz").inspect
  print "ANS: ", px.foo(ps1, ps2).inspect
#  print ps1.to_s
end

def test_6
  print "Case: 6"
  px = Reference.register($SM, 1111111111111111111111111111111)
  py = Reference.register($SM, 1111111111111122222222222222222)
  print (px + 1).inspect
  print (px + py).inspect
  print 1 + px
  print 0/px
end

def test_7
  print "Case: 7"
  px = Reference.register($SM, ["a", "b", "c"])
  p "px: ", px
  p "px.peer: ", px.peer
  
  py = Reference.register($SM, Array.new)
  for elm in px
    p "elm: ", elm
    py.push elm+"zz"
  end
  p "py: ", py
  p "py.peer", py.peer
end

def test_71
  print "Case: 71"
  px = Reference.register($SM, [1, 2, 3])
  py = Reference.register($SM, Array.new)
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
  px = Reference.register($SM, open("/etc/printcap"))
  
  for l in px
    sleep 0.1
    print l
  end
end

eval "test_"+ARGV[0]

