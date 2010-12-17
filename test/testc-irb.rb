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
require "irb"

require "deep-connect"

Thread.abort_on_exception=true
STDOUT.sync

#Tracer.on
$dc = DeepConnect.start(19998)
$deep_space = $dc.open_deep_space("localhost", 65535)

IRB.start


