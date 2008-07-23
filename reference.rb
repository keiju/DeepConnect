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

require "deep-connect/class-spec-space"

module DeepConnect
  class Reference

    # session ローカルなプロキシを生成
    #	[クラス名, 値]
    #	[クラス名, ローカルSESSION, 値]
    def Reference.serialize(deep_space, value, spec = nil)
      if spec
	return Reference.serialize_with_spec(deep_space, value, spec)
      end

      if value.kind_of? Reference
	if deep_space == value.deep_space
	  [value.class, value.csid, value.peer_id, :PEER_OBJECT]
	else
	  uuid = value.deep_space.peer_uuid.dup
	  if uuid[0] == "::ffff:127.0.0.1"
	    uuid[0] = :SAME_UUIDADDR
	  end
	    
	  [value.class, value.csid, value.peer_id, uuid]
	end
      else
	case value
	when *Organizer::immutable_classes
	  [value.class, value.class.name, value]
	else
	  object_id = deep_space.set_root(value)
	  csid = deep_space.my_csid_of(value)
	  [Reference,  csid, object_id]
	end
      end
    end

    def Reference.serialize_with_spec(deep_space, value, spec)
      case value
      when Reference
	if deep_space == value.deep_space
	  [value.class, value.csid, value.peer_id, :PEER_OBJECT]
	else
	  uuid = value.deep_space.peer_uuid.dup
	  if uuid[0] == "::ffff:127.0.0.1"
	    uuid[0] = :SAME_UUIDADDR
	  end
	    
	  [value.class, value.csid, value.peer_id, uuid]
	end
      when *Organizer::absolute_immutable_classes
	[value.class, value.class.name, value]
      else 
	case spec
	when MethodSpec::DefaultParamSpec
	  Reference.serialize(deep_space, value)
	when MethodSpec::RefParamSpec
	  object_id = deep_space.set_root(value)
	  csid = deep_space.my_csid_of(value)
	  [Reference,  csid, object_id]
	when MethodSpec::ValParamSpec
	  serialize_val(deep_space, value, spec)
	when MethodSpec::DValParamSpec
	  # 第2引数意味なし
	  [value.class, value.class.name, value]
	else
	  raise ArgumentError,
	    "argument is only specified(#{MethodSpec::ARG_SPEC.join(', ')})(#{spec})"
	end
      end
    end

    def Reference.serialize_val(deep_space, value, spec)
      case value
      when *Organizer::immutable_classes
	[value.class, value.class.name, value]
      else 
	[:VAL, value.class.name, 
	  [value.class, value.deep_connect_serialize_val(deep_space)]]
      end
    end
    
    def Reference.materialize(deep_space, type, csid, object_id, uuid=nil)
      if type == Reference
	if uuid
	  if uuid == :PEER_OBJECT
	    deep_space.root(object_id)
	  else
	    if uuid[0] == :SAME_UUIDADDR
	      uuid[0] = deep_space.peer_uuid[0].dup
	    end
	    peer_deep_space = deep_space.organizer.deep_space(uuid)
	    peer_deep_space.register_root_to_peer(object_id)
	    type.new(peer_deep_space, csid, object_id)
	  end
	else
	    type.new(deep_space, csid, object_id)
	end
      else
	if type == :VAL
	  materialize_val(deep_space, type, 
			  csid, object_id[0], object_id[1])
	else
	  # 即値
	  object_id
	end
      end
    end

    def Reference.materialize_val(deep_space, type, csid, klass, value)
      klass.deep_connect_materialize_val(deep_space, value)
    end

#     def Reference.register(deep_space, o)
#       deep_space.peer.set_root(o)
#       Reference.new(session, o.id)
#     end

    def Reference.new(deep_space, csid, peer_id)
      if r = deep_space.import_reference(peer_id)
	return r
      end
      r = super
      deep_space.register_import_reference(r)
      r
    end
    
    def initialize(deep_space, csid, peer_id)
      @deep_space = deep_space
      @csid = csid
      @peer_id = peer_id
    end
    
    attr_reader :deep_space
    attr_reader :csid
    attr_reader :peer_id
    
    def peer
      @deep_space.root(@peer_id)
    end
    
    def method_missing(method, *args, &block)
      puts "SEND MESSAGE: #{self} #{method.id2name}" if DISPLAY_METHOD_MISSING
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
    
#     def to_a
#       a = []
#       @deep_space.session.send_to(self, :to_a).each{|e| a.push e}
#       a
#     end

    def =~(other)
      @deep_space.session.send_to(self, :=~, other)
    end

    def ===(other)
      @deep_space.session.send_to(self, :===, other)
    end

    def id
      @deep_space.session.send_to(self, :id)
    end
    
    def coerce(other)
      return  other, peer
    end
    
    def inspect
      sprintf("<Reference: deep_space=%s csid=%s id=%x>", 
	      @deep_space.to_s, 
	      @csid, 
	      @peer_id) 
    end

    def deep_connect_dup
      @deep_space.session.send_to(self, :deep_connect_dup)
    end
    alias dc_dup deep_connect_dup

    def deep_connect_deep_copy
      @deep_space.session.send_to(self, :deep_connect_deep_copy)
    end
    alias dc_deep_copy deep_connect_deep_copy

  end

end
