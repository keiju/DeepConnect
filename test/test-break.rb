#!/usr/local/bin/ruby
#
#   test-retry.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

@RCS_ID='-$Id:  $-'

def foo(*b)
  puts "FOO>"
  10.times do |i| 
#  i = 0
#  while (i+=1) < 10
    puts "itr: #{i}"
    r = yield i
    puts "yield: #{r}"
  end
  puts "FOO<"
end

x = 0

foo do |e|
  x+=1
  break if x == 5
  x
end




