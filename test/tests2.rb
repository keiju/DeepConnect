#
#   tests2.rb - 
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
dc = DeepConnect.start(65533)
dc.register_service("s2ary", ["xxx"])
dc.register_service("S2ARRAY", Array)

sleep 1000




