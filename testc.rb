#!/usr/local/bin/ruby
#
#   test.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Nihon Rational Software Co.,Ltd)
#
# --
#
#   
#

@RCS_ID='-$Id:  $-'

$DEBUG = 1
require "tracer"

require "dist"

Thread.abort_on_exception=true
STDOUT.sync

#Tracer.on
org = DIST.start(19998)
session = org.open_session("localhost", 19999)
ref = session.get_service("TEST")
p ref 

ref = session.get_service("TEST1")
p ref[0]
p ref.push 3
p ref.peer_inspect




