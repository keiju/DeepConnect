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
dc.register_service("TEST", "foo")
dc.register_service("TEST1", [1, 2, 3])
dc.register_service("TEST2", ["foo", "bar", "baz"])
dc.register_service("TEST3", Array)

case ARGV[0]
when "S2"
  session = dc.open_session("localhost", 65533)
  s2ary = session.get_service("s2ary")
  dc.register_service("TEST.S2", s2ary)

  s2Array = session.get_service("S2ARRAY")
  dc.register_service("TEST.S2ARRAY", s2Array)
end

sleep 1000




