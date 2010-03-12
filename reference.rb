# encoding: UTF-8
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

    preserved = [
      :__id__, :object_id, :__send__, :public_send, :respond_to?, :send,
      :instance_eval, :instance_exec, :extend, "!".intern
    ]
    instance_methods.each do |m|
      next if preserved.include?(m.intern)
      alias_method "__deep_connect_org_#{m}", m
      undef_method m
    end

    # session ローカルなプロキシを生成
    #	[クラス名, 値]
    #	[クラス名, ローカルSESSION, 値]
    def Reference.serialize(deep_space, value, spec = nil)
      if spec
	return Reference.serialize_with_spec(deep_space, value, spec)
      end

      if value.__deep_connect_reference?
	if deep_space == value.deep_space
	  [value.__deep_connect_real_class, value.csid, value.peer_id, :PEER_OBJECT]
	else
	  uuid = value.deep_space.peer_uuid.dup
	  if uuid[0] == "127.0.0.1" || uuid[0] == "::ffff:127.0.0.1"
	    uuid[0] = :SAME_UUIDADDR
	  end
	    
	  [value.__deep_connect_real_class, value.csid, value.peer_id, uuid]
	end
      else
	case value
	when *Organizer::immutable_classes
	  [value.__deep_connect_real_class, value.__deep_connect_real_class.name, value]
	else
	  object_id = deep_space.set_root(value)
	  csid = deep_space.my_csid_of(value)
	  [Reference,  csid, object_id]
	end
      end
    end

    def Reference.serialize_with_spec(deep_space, value, spec)
      if value.__deep_connect_reference?
	if deep_space == value.deep_space
	  [value.__deep_connect_real_class, value.csid, value.peer_id, :PEER_OBJECT]
	else
	  uuid = value.deep_space.peer_uuid.dup
	  if uuid[0] == "127.0.0.1" || uuid[0] == "::ffff:127.0.0.1"
	    uuid[0] = :SAME_UUIDADDR
	  end
	    
	  [value.__deep_connect_real_class, value.csid, value.peer_id, uuid]
	end
      elsif Organizer::absolute_immutable_classes.include?(value.class)
	[value.__deep_connect_real_class, value.__deep_connect_real_class.name, value]
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
	  [value.__deep_connect_real_class, value.__deep_connect_real_class.name, value]
	else
	  raise ArgumentError,
	    "argument is only specified(#{MethodSpec::ARG_SPEC.join(', ')})(#{spec})"
	end
      end
    end

    def Reference.serialize_val(deep_space, value, spec)
      case value
      when *Organizer::immutable_classes
	[value.__deep_connect_real_class, value.__deep_connect_real_class.name, value]
      else 
	[:VAL, value.__deep_connect_real_class.name, 
	  [value.__deep_connect_real_class, value.deep_connect_serialize_val(deep_space)]]
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
    alias deepspace deep_space
    attr_reader :csid
    attr_reader :peer_id
     
    def peer
      @deep_space.root(@peer_id)
    end

    def release
      @deep_space.deregister_import_reference_id(self)
    end

#    TO_METHODS = [:to_ary, :to_str, :to_int, :to_regexp]
#    TO_METHODS = [:to_ary, :to_str, :to_int, :to_regexp, :to_splat]
    
    def method_missing(method, *args, &block)
      puts "SEND MESSAGE: #{self.inspect} #{method.id2name}" if DC::DISPLAY_MESSAGE_TRACE

#       if TO_METHODS.include?(method)
# 	return self.dc_dup.send(method)
#       end
      begin
	if iterator?
	  @deep_space.session.send_to(self, method, args, &block)
	else
	  @deep_space.session.send_to(self, method, args)
	end
#      rescue NoMethodError
#	p $@
#	p $!
#	super
      end
    end

    def asynchronus_send_with_callback(method, *args, &callback)
      @deep_space.session.asyncronus_send_to(self, method, args, callback)
    end
    alias asynchronus_send asynchronus_send_with_callback
    
#     def peer_to_s
#       @deep_space.session.send_to(self, :to_s)
#     end

#     def peer_inspect
#       @deep_space.session.send_to(self, :inspect)
#     end

#     def peer_class
#       @deep_space.session.send_to(self, :class)
#     end

#     def to_s
#       @deep_space.session.send_to(self, :to_s)
#     end
    
#     def to_a
#       a = []
#       @deep_space.session.send_to(self, :to_a).each{|e| a.push e}
#       a
#     end

#     def =~(other)
#       @deep_space.session.send_to(self, :=~, other)
#     end

#     def ===(other)
#       @deep_space.session.send_to(self, :===, other)
#     end

#     def id
#       @deep_space.session.send_to(self, :id)
#     end
    
#     def coerce(other)
#       return  other, peer
#     end

    def __deep_connect_reference?
      true
    end
    alias dc_reference? __deep_connect_reference?

    def __deep_connect_real_class
      Reference
    end
    
    class UndefinedClass;end

    def peer_class
      return @peer_class if @peer_class
      begin
	@peer_class = self.class.dc_deep_copy
      rescue
	@peer_class = UndefinedClass
      end
      @peer_class
    end

    def respond_to?(m, include_private = false)
#       m = m.intern
#       if m != :to_ary && super
#  	return true
#       end
      return true if super
      return @deep_space.session.send_to(self, :respond_to?, [m, include_private])
    end

    # ここは, オブジェクトの同値性を用いていない
#    def ==(obj)
#      return true if obj.equal?(self)
#
##      self.deep_connect_copy == obj
#      false
#    end
    def ==(obj)
      obj.__deep_connect_reference? &&
	@deep_space == obj.deep_space && 
	@peer_id == obj.peer_id
    end

    alias eql? ==

    def equal?(obj)
      self.object_id == obj.object_id
    end

    def hash
      @deep_space.object_id ^ @peer_id
    end

    def kind_of?(klass)
      if klass.__deep_connect_reference?
	@deep_space.session.send_to(self, :kind_of?, klass)
      else
	self.peer_class <= klass
      end
    end

    def nil?
      false
    end

#     def ===(other)
#       if other.__deep_connect_reference?
# 	@deep_space.session.send_to(self, :===, other)
#       else
# 	case other
# 	when Class
# 	  self.peer_class <= klass
# 	end
#       end
#     end

#     def marshal_dump
#       Reference.serialize(@deep_space, self)
#     end
    
#     def marshal_load(obj)
#       Reference.materialize(
#     end

#     def marshal_load(obj)
#       Reference.materialize(
#     end

#      def to_ary
#        if respond_to?(:to_ary)
# 	 p "AAAAAAA"
# 	 self.dc_dup.to_ary
# 	 p "BBBBBBBB"
#        else
# #	 raise NoMethodError.new("undefined method `to_ary' for #{self}@@@", :to_ary)
# 	 raise NoMethodError, "to_ary"
#        end
#      end

#     def to_str
#       if respond_to?(:to_str)
# 	self.dc_dup.to_str
#       end
#     end

#     def to_a
#       self.dc_dup.to_a
#     end

    def to_s(force = false)
      if !force && /deep-connect/ =~ caller(1).first
	unless /deep-connect\/test/ =~ caller(1).first
	  return __deep_connect_org_to_s
	end
      end

      if @deep_space.status == :SERVICING
	@deep_space.session.send_to(self, :to_s)
      else
	"(no service)"
      end
    end

    def inspect(force = false)
      if !force && /deep-connect/ =~ caller(1).first
	unless /deep-connect\/test/ =~ caller(1).first
	  return sprintf("<DC::Ref: deep_space=%s csid=%s id=%x>", 
		@deep_space.to_s, 
		@csid, 
		@peer_id)
	end
      end

      if DC::DEBUG_REFERENCE
	sprintf("<DC::Ref[deep_space=%s csid=%s id=%x]: %s>", 
		@deep_space.to_s, 
		@csid, 
		@peer_id,
		to_s) 
      else
	sprintf("<DC::Ref: %s>", to_s(true)) 
      end
    end

    def peer_inspect
      begin
	@deep_space.session.send_to(self, :inspect)
      rescue SessionServiceStopped
	sprintf("<DC::Ref[deep_space=%s csid=%s id=%x]: %s>", 
		@deep_space.to_s, 
		@csid, 
		@peer_id,
		"(service stoped)") 
      end
    end

    def my_inspect
      __deep_connect_org_inspect
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

class Object
  def __deep_connect_reference?
    false
  end
  alias dc_reference? __deep_connect_reference?

  def __deep_connect_real_class
    self.class
  end
end

class Module
  def ===(other)
    other.kind_of?(self)
  end
end

		  

  
