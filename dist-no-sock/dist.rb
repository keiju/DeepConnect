#!/usr/local/bin/ruby
#
#   dist.rb - 
#   	$Release Version: $
#   	$Revision: 1.2 $
#   	$Date: 97/02/14 15:26:45 $
#   	by Keiju ISHITSUKA(SHL Japan Inc.)
#
# --
#
#   
#

require "thread.rb"
require "mutex_m.rb"

require "dist/controller"
require "dist/event"

module DIST
  # sm.peer上のオブジェクトのプロキシを生成するファクトリ
  def Reference(sm, v)
    case v
    when Fixnum, TRUE, FALSE, nil
      v
    when Reference
      if sm == v.service_manager
	v.peer
      else
	v
      end
    else
      Reference.new(sm, v)
    end
  end

  class Reference
    # sm ローカルなプロキシを生成
    #	[クラス名, 値]
    #	[クラス名, ローカルSM, 値]
    def Reference.serialize(sm, value)
      if value.kind_of? Reference
	[value.type, value.service_manager.peer, value.peer_id]
      else
	case value
	when Fixnum, TRUE, FALSE, nil
	  [value.type, value]
	else
	  id = sm.set_root(value)
	  [Reference, sm, id]
	end
      end
    end
    
    def Reference.materialize(sm, type, *serial)
      if type == Reference
	Reference(sm, type.new(serial[0].peer, serial[1]))
      else
	serial[0]
      end
    end
    
    def Reference.register(sm, o)
      sm.peer.set_root(o)
      Reference.new(sm, o.id)
    end
    
    def initialize(sm, peer_id)
      @service_manager = sm
      @peer_id = peer_id
    end
    
    def service_manager
      @service_manager
    end
    
    def peer
      @service_manager.peer.root(@peer_id)
    end
    
    def peer_id
      @peer_id
    end
    
    def method_missing(method, *args)
      if iterator?
	@service_manager.send_to(self, method.id2name, *args) do
	  |elm|
	  yield elm
	end
      else
	@service_manager.send_to(self, method.id2name, *args)
      end
    end
    
    def to_s
      @service_manager.send_to(self, "to_s")
    end
    
    def to_a
      @service_manager.send_to(self, "to_a")
    end
    
    def coerce(other)
      return  other, peer
    end
    
    def inspect
      sprintf("<Reference: SM=%s id=%d>", @service_manager.to_s, @peer_id) 
    end
  end
end

