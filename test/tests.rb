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

$DEBUG = 1

require "tracer"

require "deep-connect/deep-connect"

Thread.abort_on_exception=true

#Tracer.on
dc = DeepConnect.start(65535)
dc.export("TEST", "foo")
dc.export("TEST1", [1, 2, 3])
dc.export("TEST2", ["foo", "bar", "baz"])
dc.export("TEST3", Array)

case ARGV[0]
when "S2"
  session = dc.open_deep_space("localhost", 65533)
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
    def foo(a, &block)
      yield [1]
      yield [2]
    end
    DeepConnect.def_method_spec(self, "VAL foo(VAL){VAL}")

    def bar(a, &block)
      yield 1, 2
      yield 3, 4
    end
#    DeepConnect.def_method_spec(self, "VAL bar(VAL){VAL}")
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

end

sleep 1000




