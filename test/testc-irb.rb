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

require "deep-connect"

Thread.abort_on_exception=true
STDOUT.sync

#Tracer.on
$org = DeepConnect.start(19998)
$session = $org.open_session("localhost", 19999)

