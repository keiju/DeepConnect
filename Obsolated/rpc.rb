#!/usr/local/bin/ruby
#
#   rpc.rb - prototype for rpc
#   	$Release Version: $
#   	$Revision: 1.2 $
#   	$Date: 91/04/20 17:24:57 $
#   	by Keiju ISHITSUKA(SHL Japan Inc.)
#
# --
#
#   
#

require "socket"

Accepter = TCPserver.open(0)
addr = gs.addr
printf "Server is on: #{addr.join(':')}"

loop do
  ns = Accepter.accept
  print ns, " is accepted\n"
  Thread.start do
    Roc.start(ns)
  end
end

class Roc
  def Roc.start(s)
    roc = new
    roc.set_socket(s)
    roc.loop
  end
  
  def set_socket(s)
    @sock = s
  end
  
  def loop
    ev = read
  end
end

class Proxy
  def 

    
  
