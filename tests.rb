#!/usr/local/bin/ruby
#
#   tests.rb - 
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

#Tracer.on
org = DIST.start(19999)
org.register_service("TEST", "foo")
org.register_service("TEST1", [1, 2, 3])

sleep 1000




