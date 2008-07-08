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
session = dc.open_deep_space("localhost", 65535)

case ARGV[0]
when "1"
  ref = session.import("TEST")
  p ref 

when "2"
  ref = session.get_service("TEST1")
  #p ref
  p ref[0]
  p ref.push 3
  p ref.peer_inspect

when "3"
  r1 = session.get_service("TEST1")
  r2 = session.get_service("TEST2")
  r1.push r2
  puts "r1= #{r1.peer_inspect}"

when "4"
  r = session.get_service("TEST1")
  r.each{|e| puts "TEST1: #{e}"}
when "4.1"
  r = session.get_service("TEST1")
  r.each{|e| puts "TEST1: #{e}"; next}

when "4.2"
  r = session.get_service("TEST1")
  a = 0
  r.each do |e| 
    puts "TEST1: #{e}"
    a += 1
    redo if a==3
  end

when "4.3"
  r = session.get_service("TEST1")
  a = 0
  r.each do |e| 
    puts e
    a += 1
    break if a==2
  end

# ruby1.9ではサポートされなくなった.
# when "4.4"
#   r = session.get_service("TEST1")
#   a = 0
#   r.each do |e| 
#     puts e
#     a += 1
#     retry if a==2
#   end


when "5"
  r = session.get_service("TEST.S2")
  p r[0]

when "6"
  a = session.get_service("TEST3")
  10.times do
    a.new(10)
  end

  ObjectSpace.garbage_collect
  puts "Sleep IN"
#  sleep 10
#  require "tracer"
#  Tracer.on
#  sleep 
when "6.2"
  a = session.get_service("TEST.S2ARRAY")
  10.times do
    a.new(10)
  end

  ObjectSpace.garbage_collect
  puts "Sleep IN"

when "7"
  foo = session.get_service("TEST7")
  p foo.foo(["a", "b"])

when "7.1"
  foo = session.get_service("TEST7")
  puts "TEST7.1a: #{foo.foo(["a", [["b"]]]).inspect}"
  puts "TEST7.1b: #{foo.bar(["a", ["b"]]).inspect}"

when "7.2"
  foo = session.get_service("TEST7")
  puts "TEST7.1a: #{foo.foo("aaaa").inspect}"
  puts "TEST7.1b: #{foo.foo("aaaa").peer_inspect}"

when "7.3"
  foo = session.get_service("TEST7")
  r1, r2 = foo.foo(["aaaa"], ["bbbb"])
  puts "TEST7.1 ret1: #{r1.inspect}"
  puts "TEST7.1 ret2: #{r2.inspect}"

when "7.4"
  foo = session.get_service("TEST7")
  r1, r2 = foo.foo(["aaaa"], ["bbbb"])
  puts "TEST7.1 ret1: #{r1.inspect}"
  puts "TEST7.1 ret2: #{r2.inspect}"


when "7.5"
  foo = session.get_service("TEST7")
  r1, r2, r3 = foo.foo(["aaaa"], ["bbbb"], ["cccc"])
  puts "TEST7.1 ret1: #{r1.inspect}"
  puts "TEST7.1 ret2: #{r2.inspect}"
  puts "TEST7.1 ret3: #{r3.inspect}"

when "7.6"
  foo = session.get_service("TEST7")
  foo.foo(1) do |ba1|
    puts "TEST7.6a ba1: #{ba1.inspect}"
  end

   foo.bar(1) do |ba1, ba2|
     puts "TEST7.6b ba1: #{ba1.inspect}"
     puts "TEST7.6b ba2: #{ba2.inspect}"
   end

when "7.7"
  foo = session.get_service("TEST7")
  foo.foo(1) do |ba1|
    puts "TEST7.6a ba1: #{ba1.inspect}"
    [1,2]
  end

when "7.8"
  foo = session.get_service("TEST7")
  p foo.foo(["a", "b"])


end

sleep 1
