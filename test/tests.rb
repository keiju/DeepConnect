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
end

sleep 1000




