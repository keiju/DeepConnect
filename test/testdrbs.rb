=begin
 distributed Ruby --- Array
 	Copyright (c) 1999-2001 Masatoshi SEKI 
=end

require 'drb/drb'

class Boo<Exception;end

class Foo
  def foo
    raise Boo
  end
  def bar
    raise "aaa"
  end

end

here = ARGV.shift
#DRb.start_service(here, [1, 2, "III", 4, "five", 6])
DRb.start_service(here, Foo.new)

puts DRb.uri




DRb.thread.join
