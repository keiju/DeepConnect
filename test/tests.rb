#
#   tests.rb - 
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

require "tracer"

require "deep-connect/deep-connect"

Thread.abort_on_exception=true

#Tracer.on
dc = DeepConnect.start(65535)
#dc.when_connected do |deep_space, port|
#  ...
#end
dc.export("TEST", "foo")
dc.export("TEST1", [1, 2, 3])
dc.export("TEST2", ["foo", "bar", "baz"])
dc.export("TEST3", Array)

case ARGV[0]
when "S2"
  session = dc.open_deep_space("localhost", 65533)
#  session = dc.open_deep_space("gentoo", 65533)
  s2ary = session.import("s2ary")
  dc.export("TEST.S2", s2ary)

  s2Array = session.import("S2ARRAY")
  dc.export("TEST.S2ARRAY", s2Array)

when "7"
  class Foo
    def foo(arg1)
      puts "TEST7: #{arg1.inspect}"
      [1, 2]
    end
    DeepConnect.def_method_spec(self, "VAL foo(VAL)")
    puts DeepConnect::Organizer.class_specs.inspect
  end


  dc.export("TEST7", Foo.new)

when "7.1"
  class Foo
    def foo(arg1)
      puts "TEST7.1a: #{arg1.inspect}"
      [1, [2]]
    end
    DeepConnect.def_method_spec(self, "VAL foo(VAL)")

    def bar(arg1)
      puts "TEST7.1b: #{arg1.inspect}"
      [1, [2]]
    end
    DeepConnect.def_method_spec(self, "DVAL bar(DVAL)")
  end


  dc.export("TEST7", Foo.new)

when "7.2"
  class Foo
    def foo(arg1)
      puts "TEST7.1a: #{arg1.inspect}"
      "gooo"
    end
    DeepConnect.def_method_spec(self, "REF foo(REF)")
  end

  dc.export("TEST7", Foo.new)

when "7.3"
  class Foo
    def foo(arg1, arg2)
      puts "TEST7.3 arg1: #{arg1.inspect}"
      puts "TEST7.3 arg2: #{arg2.inspect}"
      return [1], [2]
    end
    DeepConnect.def_method_spec(self, "VAL, VAL foo(VAL, VAL)")
  end


  dc.export("TEST7", Foo.new)

when "7.4"
  class Foo
    def foo(arg1, arg2)
      puts "TEST7.3 arg1: #{arg1.inspect}"
      puts "TEST7.3 arg2: #{arg2.inspect}"
      return [1], [2]
    end
    DeepConnect.def_method_spec(self, "VAL, REF foo(VAL, REF)")
  end


  dc.export("TEST7", Foo.new)

when "7.5"
  class Foo
    def foo(arg1, arg2, arg3)
      puts "TEST7.3 arg1: #{arg1.inspect}"
      puts "TEST7.3 arg2: #{arg2.inspect}"
      puts "TEST7.3 arg3: #{arg3.inspect}"
      return [1], [2], [3]
    end
    DeepConnect.def_method_spec(self, "VAL, *VAL foo(VAL, *VAL)")
  end


  dc.export("TEST7", Foo.new)

when "7.6"
  class Foo
    def foo0(a, &block)
      yield [1, [2]]
      yield [3, [4]]
    end

    def foo(a, &block)
      yield [5, [6]]
      yield [7, [8]]
    end
    DeepConnect.def_method_spec(self, "VAL foo(VAL){*VAL}")

    def foo2(a, &block)
      yield [9, [10]]
      yield [11, [12]]
    end
    DeepConnect.def_method_spec(self, "VAL foo2(VAL){*REF}")

    def bar(a, &block)
      yield 13, [14]
      yield 15, [16]
    end
    DeepConnect.def_method_spec(self, "VAL bar(VAL){*VAL}")
  end


  dc.export("TEST7", Foo.new)

when "7.7"
  class Foo
    def foo(a, &block)
      ret = yield [1]
      puts "TEST7.7 ret: #{ret.inspect}"
    end
    DeepConnect.def_method_spec(self, "VAL foo(VAL) VAL{VAL}")

    def bar(a, &block)
      yield 1, 2
      yield 3, 4
    end
#    DeepConnect.def_method_spec(self, "VAL bar(VAL){VAL}")
  end


  dc.export("TEST7", Foo.new)

when "7.8"
  class Foo
    def foo(arg1)
      p arg1
      [1, 2]
    end
    DeepConnect.def_method_spec(self, "foo()")
  end

  dc.export("TEST7", Foo.new)

when "7.9"
  class Foo
    def foo(a, &block)
      yield 1
      yield 2, 3
    end
  end

  dc.export("TEST7", Foo.new)



when "8"

  DeepConnect::MESSAGE_DISPLAY = true
  
  class Foo
    def foo(i)
      i+=1
      if i == 1000
	raise "バックトレーステスト"
      end
      foo(i)
    end
  end

  dc.export("TEST8", Foo.new)

when "9"

  DeepConnect.def_method_spec(Array, :method=> :-, :args=> "VAL")
  DeepConnect.def_method_spec(Array, :method=> :&, :args=> "VAL")
  DeepConnect.def_method_spec(Array, :method=> :|, :args=> "VAL")
  DeepConnect.def_method_spec(Array, :method=> :<=>, :args=> "VAL")
  DeepConnect.def_method_spec(Array, :method=> :==, :args=> "VAL")
  dc.export("Array", [1, 2])

when "9.1"
  
  DeepConnect::MESSAGE_DISPLAY = true
  dc.export("regexp", /foo/)

when "9.2"

#  DeepConnect::MESSAGE_DISPLAY = true
  DeepConnect.def_single_method_spec(Regexp, :method=> :union, :args=> "*DVAL")
  dc.export("Regexp", Regexp)

when "9.3"
  
  dc.export("range", 1..2)

when "9.4"
#  DeepConnect::MESSAGE_DISPLAY = true

  DeepConnect.def_method_spec(Hash, "merge(VAL)")
  DeepConnect.def_method_spec(Hash, :method=> :merge!, :args=> "VAL")
  DeepConnect.def_method_spec(Hash, "replace(VAL)")
  DeepConnect.def_method_spec(Hash, "update(VAL)")
  
  dc.export("hash", {1=>2, 2=>3})

when "9.5"

  St = Struct.new("Foo", :foo, :bar)
  dc.export("St", St)
  dc.export("st", St.new([1,2], "baz"))

  class Foo
    def foo
      St.new([3,4], "boo")
    end
    DeepConnect.def_method_spec(self, "VAL foo()")

    def baz
      St.new([3,4], "boo")
    end
    DeepConnect.def_method_spec(self, "DVAL baz()")
    
  end
  
  dc.export("Foo", Foo)

when "10"

  class Foo
    def initialize
      @foo = "foo"
      @bar = [1, 2]
    end

    def foo
      self
    end
    DeepConnect.def_method_spec(self, "VAL foo()")
    
  end
  dc.export("Foo", Foo)

when "10.1"
  
  DeepConnect.def_single_method_spec(File, "VAL open()")
  dc.export("File", File)

when "10.2"

  class Foo
    def initialize
      @foo = "foo"
      @bar = [1, [2, 3]]
    end
  end
  dc.export("Foo", Foo)

when "11"

  dc.export("ary", [[1,2], [3,4]])

when "11.1"

  class Foo
    def initialize
      @ary = [[1,2], [3,4]]
    end

    def foo
      @ary.each do |e|
	yield  *e
      end
    end
  end

  dc.export("Foo", Foo)

when "11.2"

  foo = {1=>2, 2=>3}

  dc.export("foo", foo)

when "12"
  require "thread"

  class BH
    def initialize
      @a = ["foo", "bar"]
    end

    def each(&block)
      while e = @a.pop
#	block.call e
	yield e
      end
    end

  end

  dc.export("BH", BH)

when "13"

  class Foo
    def foo
      1
    end
    def slp(time)
      sleep time
    end
  end

  dc.export("foo", Foo.new)

when "14"
  $dc = dc

  class Foo
    def foo
      deepspace = $dc.open_deep_space("gentoo", 65533)
      s2ary = deepspace.import("s2ary")
      $dc.export("TEST.S2", s2ary)

      s2Array = deepspace.import("S2ARRAY")
      $dc.export("TEST.S2ARRAY", s2Array)
    end
  end
  dc.export("foo", Foo.new)


when "14.1"
  $dc = dc

  require "thread"
  class Foo
    def foo
      $cv.broadcast
    end
  end

  dc.export("foo", Foo.new)

  mutex = Mutex.new
  $cv = ConditionVariable.new

  puts "WAIT"
  mutex.synchronize do
    $cv.wait(mutex)
  end

  deepspace = $dc.open_deep_space("gentoo", 65533)
  s2ary = deepspace.import("s2ary")
  $dc.export("TEST.S2", s2ary)
  
  s2Array = deepspace.import("S2ARRAY")
  $dc.export("TEST.S2ARRAY", s2Array)

when "15"
  
  DeepConnect.def_interface(Array, :[])
  DeepConnect.def_interface(Array, :push)
  DeepConnect.def_interface(Array, :inspect)

when "16"
  class Foo
    def foo
      raise Boo
    end
    def bar
      raise "aaa"
    end

    def baz
      1
    end
  end
  
  dc.export("foo", Foo.new)

when "18"

  class Foo;end

  dc.export("Foo", Foo)
  puts "SLEEP IN"
  sleep 5
  puts "GC start"
  GC.start

when "18.1"

  session = dc.open_deep_space("localhost", 65533)
#  session = dc.open_deep_space("gentoo", 65533)

  s2Array = session.import("S2ARRAY")
  s2a = s2Array.new
  s2a.release
  dc.export("TEST.18.1", s2a)

when "19"
  dc.when_connected {false}

when "19.2"
  session = dc.open_deep_space("localhost", 65533)
#  session = dc.open_deep_space("gentoo", 65533)

  s2Array = session.import("S2ARRAY")
  s2a = s2Array.new
  s2a.release
  dc.export("TEST.19.2", s2a)
    
end

sleep 1000




