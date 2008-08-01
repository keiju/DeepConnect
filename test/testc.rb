#
#   testc.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

$DEBUG = 1
require "tracer"

require "deep-connect/deep-connect"

Thread.abort_on_exception=true
STDOUT.sync

#Tracer.on
dc = DeepConnect.start(65534)
deepspace = dc.open_deep_space("localhost", 65535)
#deepspace = dc.open_deep_space("gentoo", 65535)

case ARGV[0]
when "1"
  ref = deepspace.import("TEST")
  p ref 

when "2"
  ref = deepspace.get_service("TEST1")
  #p ref
  p ref[0]
  p ref.push 3
  puts ref.peer_inspect

when "3"
  r1 = deepspace.get_service("TEST1")
  r2 = deepspace.get_service("TEST2")
  r1.push r2
  puts "r1= #{r1.peer_inspect}"

when "4"
  r = deepspace.get_service("TEST1")
  r.each{|e| puts "TEST1: #{e}"}
when "4.1"
  r = deepspace.get_service("TEST1")
  r.each{|e| puts "TEST1: #{e}"; next}

when "4.2"
  r = deepspace.get_service("TEST1")
  a = 0
  r.each do |e| 
    puts "TEST1: #{e}"
    a += 1
    redo if a==3
  end

when "4.3"
  r = deepspace.get_service("TEST1")
  a = 0
  r.each do |e| 
    puts e
    a += 1
    break if a==2
  end

when "4.4"
  r = deepspace.get_service("TEST1")
  a = 0
  r.each do |e| 
    puts e
    a += 1
    raise "foo" if a==2
  end


# ruby1.9ではサポートされなくなった.
# when "4.4"
#   r = deepspace.get_service("TEST1")
#   a = 0
#   r.each do |e| 
#     puts e
#     a += 1
#     retry if a==2
#   end


when "5"
  r = deepspace.get_service("TEST.S2")
  sleep 5
  p r[0]

when "6"
  a = deepspace.get_service("TEST3")
  1000.times do
    a.new(10)
  end

  ObjectSpace.garbage_collect
  puts "Sleep IN"
  sleep 10
#  require "tracer"
#  Tracer.on
#  sleep 
when "6.2"
  a = deepspace.get_service("TEST.S2ARRAY")
  10.times do
    a.new(10)
  end

  ObjectSpace.garbage_collect
  puts "Sleep IN"

when "7"
  foo = deepspace.get_service("TEST7")
  puts "TEST7: foo: #{foo.inspect}"
  ret = foo.foo(["a", "b"])
  puts "TEST7: #{ret.inspect}"

when "7.1"
  foo = deepspace.get_service("TEST7")
  puts "TEST7.1a: #{foo.foo(["a", [["b"]]]).inspect}"
  puts "TEST7.1b: #{foo.bar(["a", ["b"]]).inspect}"

when "7.2"
  foo = deepspace.get_service("TEST7")
  puts "TEST7.1a: #{foo.foo("aaaa").inspect}"
  puts "TEST7.1b: #{foo.foo("aaaa").peer_inspect}"

when "7.3"
  foo = deepspace.get_service("TEST7")
  r1, r2 = foo.foo(["aaaa"], ["bbbb"])
  puts "TEST7.1 ret1: #{r1.inspect}"
  puts "TEST7.1 ret2: #{r2.inspect}"

when "7.4"
  foo = deepspace.get_service("TEST7")
  r1, r2 = foo.foo(["aaaa"], ["bbbb"])
  puts "TEST7.1 ret1: #{r1.inspect}"
  puts "TEST7.1 ret2: #{r2.inspect}"


when "7.5"
  foo = deepspace.get_service("TEST7")
  r1, r2, r3 = foo.foo(["aaaa"], ["bbbb"], ["cccc"])
  puts "TEST7.1 ret1: #{r1.inspect}"
  puts "TEST7.1 ret2: #{r2.inspect}"
  puts "TEST7.1 ret3: #{r3.inspect}"

when "7.6"

  puts "LOCAL:"
  class Foo
    def foo(a, &block)
      yield [1, [1]]
      yield [2, [1]]
    end
    
    def foo2(a, &block)
      yield [1, [1]]
      yield [2, [1]]
    end
    
    def bar(a, &block)
      yield 1, 2
      yield 3, 4
    end
  end
  foo = Foo.new
  foo.foo(1) do |ba1, ba2|
    puts "TEST7.6a ba1: #{ba1.inspect}"
    puts "TEST7.6a ba2: #{ba2.inspect}"
  end

  foo.foo2(1) do |ba1|
    puts "TEST7.6c ba1: #{ba1.inspect}"
  end

  foo.bar(1) do |ba1, ba2|
    puts "TEST7.6b ba1: #{ba1.inspect}"
    puts "TEST7.6b ba2: #{ba2.inspect}"
  end


  puts "REMOTE:"
  foo = deepspace.get_service("TEST7")

  foo.foo0(1) do |ba1, ba2|
    puts "TEST7.60 ba1: #{ba1.inspect}"
    puts "TEST7.60 ba2: #{ba2.inspect}"
  end

  foo.foo0(1) do |ba1|
    puts "TEST7.61 ba1: #{ba1.inspect}"
  end

  foo.foo(1) do |ba1, ba2|
    puts "TEST7.6a ba1: #{ba1.inspect}"
    puts "TEST7.6a ba2: #{ba2.inspect}"
  end

  foo.foo2(1) do |ba1|
    puts "TEST7.6c ba1: #{ba1.inspect}"
  end

  foo.bar(1) do |ba1, ba2|
    puts "TEST7.6b ba1: #{ba1.inspect}"
    puts "TEST7.6b ba2: #{ba2.inspect}"
  end

when "7.7"
  foo = deepspace.get_service("TEST7")
  foo.foo(1) do |ba1|
    puts "TEST7.6a ba1: #{ba1.inspect}"
    [1,2]
  end

when "7.8"
  foo = deepspace.get_service("TEST7")
  p foo.foo(["a", "b"])

when "8"
  foo = deepspace.import("TEST8")
  p foo.foo(0)

when "9"

  a = deepspace.import("Array")
  b = a - [1,2]
  p b.peer_inspect

when "9.1"

  DeepConnect::MESSAGE_DISPLAY = true

  r = deepspace.import("regexp")
  p r.peer_inspect
  p r.methods
  p r =~ "foo"
  p "foo" =~ r
  p r === "foo"
#  p "foo" === r

when "9.2"

  DeepConnect::MESSAGE_DISPLAY = true
  r = deepspace.import("Regexp")
  p r
  p  r.union(/foo/, /bar/)

when "9.3"

  r = deepspace.import("range")
  p r

when "9.4"
#  DeepConnect::MESSAGE_DISPLAY = true

  r = deepspace.import("hash")
  p r.peer_inspect

  s = {3=>4}
  r2 = r.merge(s)
  p r.peer_inspect
  p r2.peer_inspect

when "9.5"

  s = deepspace.import("st")
  p s
  p s.peer_inspect

  St = Struct.new("Foo", :foo, :bar)

  Foo = deepspace.import("Foo")
  p foo = Foo.new
  p foo.foo
  p foo.baz

when "10"

  class Foo
  end

  RFoo = deepspace.import("Foo")
  p foo = RFoo.new
  p foo.foo

when "10.1"

  RFile = deepspace.import("File")
  p foo = RFile.open("/etc/passwd")
  foo.gets


when "10.2"

  class Foo
  end

  RFoo = deepspace.import("Foo")
  p foo = RFoo.new
  p foo.dc_dup

  p foo.dc_deep_copy

when "11"
  
  ary = deepspace.import("ary")
  ary.each{|x1, y1| puts "x1=#{x1.inspect} y1=#{y1.inspect}"}


when "11.1"
  
  RFoo = deepspace.import("Foo")
  p foo = RFoo.new
  foo.foo{|x1, y1| puts "x1=#{x1.inspect} y1=#{y1.inspect}"}

when "11.1.1"

  puts "LOCAL:"
  ary = [[1,2], [3,4]]
  ary.each{|*x1| puts "x1=#{x1.inspect}"}

  
  puts "REMOTE:"
  RFoo = deepspace.import("Foo")
  p foo = RFoo.new
  foo.foo{|*x1| puts "x1=#{x1.inspect}"}


when "11.1.2"
  
  puts "LOCAL:"
  ary = [[1,2], [3,4]]
  ary.each{|x1| puts "x1=#{x1.inspect}"}

  puts "REMOTE:"
  RFoo = deepspace.import("Foo")
  p foo = RFoo.new
  foo.foo{|x1| puts "x1=#{x1.inspect}"}

when "11.1.3"
  
  puts "LOCAL:"
  ary = [[1,2], [3,4]]
  ary.each{|x1, x2, x3| puts "x1=#{x1.inspect} x2=#{x2.inspect} x3=#{x3.inspect}"}

  puts "REMOTE:"
  RFoo = deepspace.import("Foo")
  p foo = RFoo.new
  foo.foo{|x1, x2, x3| puts "x1=#{x1.inspect} x2=#{x2.inspect} x3=#{x3.inspect}"}

when "11.2"
  puts "LOCAL"
  foo = {1=>2, 2=>3}
  for k, v in foo
    p k
    p v
  end

  puts "REMOTE: 1 variable"
  foo = deepspace.import("foo")
  for k in foo
    p k
    p k[0], k[1]
  end

  puts "REMOTE: 2 variable"
  foo = deepspace.import("foo")
  for k,v in foo
    p k, v
  end

when "12"
  
  RBH = deepspace.import("BH")
  foo = RBH.new
  foo.each{|e| p e}

when "13"
  sleep 1
  deepspace.close
  sleep 1

when "13.1"
  deepspace.close
  sleep 1

when "13.2"
  
  foo = deepspace.import("foo")
  p foo.foo
  Thread.start do 
    begin
      foo.slp 5
    rescue
      puts "XXXXXXXXXX:#{$!}"
    end
  end
  
  deepspace.close
  sleep 1

when "13.3"
  # スリープ中にサーバーを切断するテスト
  foo = deepspace.import("foo")
  sleep 100
  foo.foo

when "14"
  foo = deepspace.import("foo")
  foo.foo

when "17"

  foo = deepspace.import("foo")
#  foo.foo{sleep 1; p 1; 1}
  foo.foo{1}
  sleep 2
  
end

sleep 1
