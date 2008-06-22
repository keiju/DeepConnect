#!/usr/local/bin/ruby
#
#   proxy.rb - 
#   	$Release Version: $
#   	$Revision: 1.2 $
#   	$Date: 91/04/20 17:24:57 $
#   	by Keiju ISHITSUKA(SHL Japan Inc.)
#
# --
#
#   
#

class ServiceManager
  def send_to(peer, method, *args)
    begin
      ret = peer.send(method, *args)
      return ret
    rescue
      
    end
  end
end

class Proxy
  def initialize(sm, peer)
    @service_manager = sm
    @peer = peer
  end
  
  def method_missing(method, *args)
    @service_manager.send_to(@peer, method, *args)
  end
end

sm = ServiceManager.new

px = Proxy.new(sm, 1)
print px + 1


    
