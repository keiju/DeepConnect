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
  # session.peer上のオブジェクトのプロキシを生成するファクトリ
  def Reference(session, v)
    case v
    when Fixnum, TRUE, FALSE, nil, String
      v
    when Reference
      if session == v.session
	v.peer
      else
	v
      end
    when Module
      ReferenceClass(session, v)
    else
      Reference.new(session, v)
    end
  end
  module_function :Reference

  def ReferenceClass(session, klass)
    rklass = Class.new(ReferenceClass)
#    rklass.module_eval {
#      def foo;end
#    }
  end

  class Reference
    # session ローカルなプロキシを生成
    #	[クラス名, 値]
    #	[クラス名, ローカルSESSION, 値]
    def Reference.serialize(session, value)
      if value.kind_of? Reference
	if session == value.session
	  [value.class, value.peer_id, :PEER_OBJECT]
	else
	  [value.class, value.peer_id, value.session.peer_uuid]
	end
      else
	case value
	when Fixnum, TRUE, FALSE, nil, Symbol, String
	  [value.class, value]
	else
	  object_id = session.set_root(value)
	  [Reference,  object_id]
	end
      end
    end
    
    def Reference.materialize(session, type, object_id, uuid=nil)
      if type == Reference
#puts "MAT0: #{serial.collect{|e| e.to_s}.join(', ')}"
#puts "MAT1: uuid=#{uuid}"
#puts "MAT1: #{session.organizer.session(uuid)}"
#puts "MAT2: #{type.new(session.organizer.session(serial[0]), serial[1]).inspect}"
#	DeepConnect::Reference(session, type.new(session.organizer.session(serial[0]), serial[1]))
	if uuid
#	  if session.organizer.local_id == uuid[1]
	  if uuid == :PEER_OBJECT
	    session.root(object_id)
	  else
	    peer_session = session.organizer.session(uuid)
	    type.new(session.organizer.session(uuid), object_id)
	  end
	else
	  type.new(session, object_id)
	end
      else
	# 即値
	object_id
      end
    end
    
    def Reference.register(session, o)
      session.peer.set_root(o)
      Reference.new(session, o.id)
    end
    
    def initialize(session, peer_id)
      @session = session
      @peer_id = peer_id
    end
    
    def session
      @session
    end
    
    def peer
      @session.root(@peer_id)
    end
    
    def peer_id
      @peer_id
    end
    
    def method_missing(method, *args)
#puts "METHOD_MISSING: #{method.id2name} "
      if iterator?
	@session.send_to(self, method, *args) do
	  |elm|
	  yield elm
	end
      else
	@session.send_to(self, method, *args)
      end
    end
    
     def peer_to_s
       @session.send_to(self, :to_s)
     end
     def peer_inspect
       @session.send_to(self, :inspect)
     end
    
#     def to_s
#       @session.send_to(self, :to_s)
#     end
    
#     def to_a
#       @session.send_to(self, :to_a)
#     end
    
    def coerce(other)
      return  other, peer
    end
    
    def inspect
      sprintf("<Reference: session=%s id=%x>", @session.to_s, @peer_id) 
    end
  end

end
