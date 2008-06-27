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
session = dc.open_session("localhost", 65535)

case ARGV[0]
when "1"
  ref = session.get_service("TEST")
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
  r.each{|e| puts e}

when "4.1"
  r = session.get_service("TEST1")
  r.each{|e| puts e; next}

when "4.2"
  r = session.get_service("TEST1")
  a = 0
  r.each do |e| 
    puts e
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
end

sleep 1
