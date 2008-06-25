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
dc = DeepConnect.start(19998)
session = dc.open_session("localhost", 19999)
ref = session.get_service("TEST")
p ref 

ref = session.get_service("TEST1")
#p ref
p ref[0]
p ref.push 3
p ref.peer_inspect



