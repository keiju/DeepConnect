#
#   reference.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

module DeepConnect
  class Reference

    # session ローカルなプロキシを生成
    #	[クラス名, 値]
    #	[クラス名, ローカルSESSION, 値]
    def Reference.serialize(deep_space, value)
      if value.kind_of? Reference
	if deep_space == value.deep_space
	  [value.class, value.peer_id, :PEER_OBJECT]
	else
	  [value.class, value.peer_id, value.deep_space.peer_uuid]
	end
      else
	case value
	when Fixnum, TRUE, FALSE, nil, Symbol, String
	  [value.class, value]
	else
	  object_id = deep_space.set_root(value)
	  [Reference,  object_id]
	end
      end
    end
    
    def Reference.materialize(deep_space, type, object_id, uuid=nil)
      if type == Reference
	if uuid
	  if uuid == :PEER_OBJECT
	    deep_space.root(object_id)
	  else
<<<<<<< .working
	    peer_session = session.organizer.session(uuid)
	    peer_session.register_root_to_peer(object_id)
	    type.new(peer_session, object_id)
=======
	    peer_deep_space = deep_space.organizer.deep_space(uuid)
	    peer_deep_space.register_root_to_peer(object_id)
	    type.new(peer_deep_space, object_id)
>>>>>>> .merge-right.r54
	  end
	else
	    type.new(deep_space, object_id)
	end
      else
	# 即値
	object_id
      end
    end

#     def Reference.register(deep_space, o)
#       deep_space.peer.set_root(o)
#       Reference.new(session, o.id)
#     end

    def Reference.new(deep_space, peer_id)
      if r = deep_space.import_reference(peer_id)
	return r
      end
      r = super
      deep_space.register_import_reference(r)
      r
    end
    
    def initialize(deep_space, peer_id)
      @deep_space = deep_space
      @peer_id = peer_id
    end
    
    def deep_space
      @deep_space
    end
    
    def peer
      @deep_space.root(@peer_id)
    end
    
    def peer_id
      @peer_id
    end

    def method_missing(method, *args, &block)
#puts "METHOD_MISSING: #{method.id2name} "
      if iterator?
	@deep_space.session.send_to(self, method, *args, &block)
      else
	@deep_space.session.send_to(self, method, *args)
      end
    end
    
    def peer_to_s
      @deep_space.session.send_to(self, :to_s)
    end

    def peer_inspect
      @deep_space.session.send_to(self, :inspect)
    end

    def peer_class
      @deep_space.session.send_to(self, :class)
    end

#     def to_s
#       @deep_space.session.send_to(self, :to_s)
#     end

    def to_a
      a = []
      @deep_space.session.send_to(self, :to_a).each{|e| a.push e}
      a
    end

    def id
      @deep_space.session.send_to(self, :id)
    end
    
    def coerce(other)
      return  other, peer
    end
    
    def inspect
      sprintf("<Reference: deep_space=%s id=%x>", @deep_space.to_s, @peer_id) 
    end
  end

end
