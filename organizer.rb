#
#   organizer.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#
require "forwardable"

require "deep-connect/class-spec-space"

module DeepConnect
  class Organizer
    @CLASS_SPEC_SPACE = ClassSpecSpace.new(:local)
    
    extend SingleForwardable

    def_delegator :@CLASS_SPEC_SPACE, :class_specs
    def_delegator :@CLASS_SPEC_SPACE, :def_method_spec
    def_delegator :@CLASS_SPEC_SPACE, :def_single_method_spec
    def_delegator :@CLASS_SPEC_SPACE, :def_interface
    def_delegator :@CLASS_SPEC_SPACE, :def_single_interface
    def_delegator :@CLASS_SPEC_SPACE, :method_spec
    def_delegator :@CLASS_SPEC_SPACE, :class_spec_id_of
  end
end

require "deep-connect/accepter"
require "deep-connect/evaluator"
require "deep-connect/deep-space"
require "deep-connect/port"
require "deep-connect/event"
require "deep-connect/cron"
require "deep-connect/exceptions"


trap("SIGPIPE", "IGNORE")

module DeepConnect

  class Organizer
    def initialize
      @shallow_connect = false

      @accepter = Accepter.new(self)
      @evaluator = Evaluator.new(self)

      @services = {}
      @deep_spaces = {}

      @cron = Cron.new(self)

      @when_connect_proc = proc{true}
      @when_disconnect_proc = proc{}

      @local_id_mutex = Mutex.new
      @local_id_cv = ConditionVariable.new
      @local_id = nil
    end

    attr_accessor :shallow_connect
    alias shallow_connect? shallow_connect

    attr_reader :accepter
    attr_reader :evaluator

    def tick
      @cron.tick
    end

    def deep_spaces
      @deep_spaces
    end

    def local_id
      @local_id_mutex.synchronize do
	while !@local_id
	  @local_id_cv.wait(@local_id_mutex)
	end
      end
      @local_id
    end

    def start(service)
      @accepter.open(service)
      @local_id = @accepter.port_number
      @local_id_cv.broadcast

      @accepter.start
      @cron.start
    end

    def stop
      @accepter.stop
    end

    # client sesssion開始
    def open_deep_space(ipaddr, port)
      sock = TCPSocket.new(ipaddr, port)
      port = Port.new(sock)
      init_session_ev = Event::InitSessionEvent.new(local_id)
      port.export init_session_ev
      connect_deep_space_with_port(port)
    end
    alias open_deepspace open_deep_space

    def close_deep_space(deep_space)
      disconnect_deep_space(deep_space)
    end
    alias close_deepspace close_deep_space

    def deep_space(peer_id, &block)
      if deep_space = @deep_spaces[peer_id]
	return deep_space
      end

      # セッションを自動的に開く
      begin
	deep_space = open_deep_space(*peer_id)
	block.call deep_space if block_given?
	deep_space
      rescue ConnectionRefused
	puts "WARN: クライアント(#{peer_id}への接続が拒否されました"
	raise
      end
    end
    alias deepspace deep_space

    # sessionサービス開始
    def connect_deep_space_with_port(port, local_id = nil)
      deep_space = DeepSpace.new(self, port, local_id)
      port.attach(deep_space.session)
#      uuid = session.peer_id unless uuid
      if @deep_spaces[deep_space.peer_uuid]
	# ポート番号が再利用されているときは, 既存の方はすでにおなくな
	# りになっている
	old = @deep_spaces[deep_space.peer_uuid]
	puts "INFO: port no recyicled"
	puts "INFO: disconnect recycled deep_space: #{old}"

	disconnect_deep_space(old, :SESSION_CLOSED)
      end
      unless @when_connect_proc.call deep_space, port
	puts "CONNECT Canceld DeepSpace: #{deep_space.peer_uuid}" if $DEBUG
	connect_ev = Event::ConnectResult.new(false)
	port.export connect_ev

	disconnect_deep_space(deep_space)
	DC::Raise ConnectCancel, deep_space
      end

      connect_ev = Event::ConnectResult.new(true)
      port.export connect_ev

      ev = port.import
      if ev.kind_of?(Event::ConnectResult)
	unless ev.result
	  DC::Raise ConnectionRefused, deep_space
	end
      else
	DC::Raise ProtocolError, deep_space
      end

      @deep_spaces[deep_space.peer_uuid] = deep_space

      puts "CONNECT DeepSpace: #{deep_space.peer_uuid}" if $DEBUG
      deep_space.connect
      deep_space
    end
    alias connect_deepspace_with_port connect_deep_space_with_port

    def disconnect_deep_space(deep_space, *opts)
      @deep_spaces.delete(deep_space.peer_uuid)
      deep_space.disconnect(*opts)
      @when_disconnected_proc.call(deep_space, opts)
    end

    def when_connected(&block)
      @when_connect_proc = block
    end

    def when_disconnected(&block)
      @when_disconnect_proc = block
    end

    #
    def keep_alive
      puts "KEEP ALIVE: Start" if DISPLAY_KEEP_ALIVE
      for uuid, deep_space in @deep_spaces.dup
	unless deep_space.session.keep_alive
	  disconnect_deep_space(deep_space, :SESSION_CLOSED)
	end
      end
    end


    # services
    def register_service(name, obj)
      @services[name] = obj
    end
    alias export register_service

    def service(name)
      unless @services.key?(name)
	return :DEEPCONNECT_NO_SUCH_SERVICE
      end
      @services[name]
    end
    alias import service

    def release_object(obj)
      for id, dspace in @deep_spaces
	dspace.release_object(obj)
      end
    end

    def id2obj(id)
      for peer_id, s in @deep_spaces.dup
	if o = s.root(id) and !o.kind_of?(IllegalObject)
	  return o
	end
      end
      IllegalObject.new
#      DC::InternalError "deep_spaceにid(=#{id})をobject_idとするオブジェクトが登録されていません.)"
    end

    @@ABSOLUTE_IMMUTABLE_CLASSES = [
      NilClass,
      TrueClass,
      FalseClass,
      Symbol,
      Fixnum,
    ]

    @@DEFAULT_IMMUTABLE_CLASSES = [
      Numeric,
      String,
      Regexp,
      MatchData,
      Range,
      Time,
      File::Stat,
    ]
    
    @@IMMUTABLE_CLASSES = @@ABSOLUTE_IMMUTABLE_CLASSES + 
      @@DEFAULT_IMMUTABLE_CLASSES

    def self.absolute_immutable_classes
      @@ABSOLUTE_IMMUTABLE_CLASSES
    end
    def self.default_immutable_classes
      @@DEFAULT_IMMUTABLE_CLASSES
    end
    def self.immutable_classes
      @@IMMUTABLE_CLASSES
    end

    def_interface(Exception, :message)

    def_method_spec(Exception, "VAL backtrace()")
    def_interface(Exception, :backtrace)

    def_method_spec(Exception, "REF set_backtrace(VAL)")

    def_method_spec(Object, "VAL to_a()")
    #def_method_spec(Object, "VAL to_s()")
    def_method_spec(Object, "VAL to_ary()")
    def_method_spec(Object, "VAL to_str()")
    def_method_spec(Object, "VAL to_int()")
    def_method_spec(Object, "VAL to_regexp()")
    def_method_spec(Object, "VAL to_splat()")

    def_method_spec(Array, :method=> :-, :args=> "VAL")
    def_method_spec(Array, :method=> :&, :args=> "VAL")
    def_method_spec(Array, :method=> :|, :args=> "VAL")
    def_method_spec(Array, :method=> :<=>, :args=> "VAL")
    def_method_spec(Array, :method=> :==, :args=> "VAL")

    #def_single_method_spec(Regexp, :method=> :union, :args=> "*DVAL")

    def_method_spec(Hash, "merge(VAL)")
    def_method_spec(Hash, :method=> :merge!, :args=> "VAL")
    def_method_spec(Hash, "replace(VAL)")
    def_method_spec(Hash, "update(VAL)")

  end
end
