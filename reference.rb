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
    def Reference.serialize(deep_space, value, spec = nil)
      if spec
	return Reference.serialize_with_spec(deep_space, value, spec)
      end

      if value.kind_of? Reference
	if deep_space == value.deep_space
	  [value.class, value.class.name, value.peer_id, :PEER_OBJECT]
	else
	  [value.class, value.class.name, value.peer_id, value.deep_space.peer_uuid]
	end
      else
	case value
	when *Organizer::default_mutal_classes
	  [value.class, value.class.name, value]
	else
	  object_id = deep_space.set_root(value)
	  [Reference,  value.class.name, object_id]
	end
      end
    end

    def Reference.serialize_with_spec(deep_space, value, spec)
      if value.kind_of? Reference
	if deep_space == value.deep_space
	  [value.class, value.class.name, value.peer_id, :PEER_OBJECT]
	else
	  [value.class, value.class.name, value.peer_id, value.deep_space.peer_uuid]
	end
      else
	case spec
	when MethodSpec::DefaultParamSpec
	  Reference.serialize(deep_space, value)
	when MethodSpec::RefParamSpec
	  object_id = deep_space.set_root(value)
	  [Reference,  value.class.name, object_id]
	when MethodSpec::ValParamSpec
	  serialize_val(deep_space, value, spec)
	when MethodSpec::DValParamSpec
	  [value.class, value.class.name, value]
	else
	  raise ArgumentError,
	    "argument is only specified(#{MethodSpec::ARG_SPEC.join(', ')})(#{spec})"
	end
      end
    end

    def Reference.serialize_val(deep_space, value, spec)
      case value
      when Array
	[:VAL, value.class.name, 
	  [value.class, value.collect{|e| Reference.serialize(deep_space, e)}]]
      when Hash
	[:VAL, value.class.name, 
	    [value.class,
	    value.collect{|k, v| 
	      [Reference.serialize(deep_space, k), 
		Reference.serialize(deep_space, v)]}]]
      when Struct
	[:VAL, value.class.name, 
	  [value.class,
	    value.to_a.collect{|e| Reference.serialize(deep_space, e)}]]
      when *Organizer::default_mutal_classes
	[value.class, value.class.name, value]
      else
	raise ArgumentError,
	  "method spec VAL is support only Array, Hash, Struct(#{value.inspect})"
      end
    end
    
    def Reference.materialize(deep_space, type, class_name, object_id, uuid=nil)
      if type == Reference
	if uuid
	  if uuid == :PEER_OBJECT
	    deep_space.root(object_id)
	  else
	    peer_deep_space = deep_space.organizer.deep_space(uuid)
	    peer_deep_space.register_root_to_peer(object_id)
	    type.new(peer_deep_space, class_name, object_id)
	  end
	else
	    type.new(deep_space, class_name, object_id)
	end
      else
	if type == :VAL
	  materialize_val(deep_space, type, 
			  class_name, object_id[0], object_id[1])
	else
	  # 即値
	  object_id
	end
      end
    end

    def Reference.materialize_val(deep_space, type, class_name, klass, value)
      case value
      when Array
	ary = klass.new
	value.each{|e| ary.push Reference.materialize(deep_space, *e)}
	ary
      when Hash
	h = klass.new
	value.each do |k, v| 
	  key = Reference.materialize(*k)
	  value = Reference.materialize(*v)
	  h[k] = v
	end
	h
      when Struct
	s = klass.new(*value.collect{|e| Reference.materialize(deep_space, *e)})
      end
    end

#     def Reference.register(deep_space, o)
#       deep_space.peer.set_root(o)
#       Reference.new(session, o.id)
#     end

    def Reference.new(deep_space, class_name, peer_id)
      if r = deep_space.import_reference(peer_id)
	return r
      end
      r = super
      deep_space.register_import_reference(r)
      r
    end
    
    def initialize(deep_space, class_name, peer_id)
      @deep_space = deep_space
      @class_name = class_name
      @peer_id = peer_id
    end
    
    attr_reader :deep_space
    attr_reader :class_name
    attr_reader :peer_id
    
    def peer
      @deep_space.root(@peer_id)
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
      sprintf("<Reference: deep_space=%s class=%s id=%x>", 
	      @deep_space.to_s, 
	      @class_name, 
	      @peer_id) 
    end

  end

end
