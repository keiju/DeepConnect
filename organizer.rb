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

require "deep-connect/accepter"
require "deep-connect/evaluator"
require "deep-connect/deep-space"
require "deep-connect/port"
require "deep-connect/event"

require "deep-connect/class-spec-space"

trap("SIGPIPE", "IGNORE")

module DeepConnect
  class Organizer

    def initialize
      @accepter = Accepter.new(self)
      @deep_spaces = {}
      @evaluator = Evaluator.new(self)
#      @naming = Naming.new
      @naming = {}

      @local_id_mutex = Mutex.new
      @local_id_cv = ConditionVariable.new
      @local_id = nil

    end

    attr_reader :accepter
    attr_reader :evaluator
#    attr_reader :naming

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
    end

    def stop
      @accepter.close
    end

    def deep_space(peer_id, &block)
      if deep_space = @deep_spaces[peer_id]
	return deep_space
      end

      # セッションを自動的に開く
      deep_space = open_deep_space(*peer_id)
      block.call deep_space if block_given?
      deep_space
    end
    alias deepspace deep_space

    # sessionサービス開始
    def connect_deep_space_with_port(port, local_id = nil)
      deep_space = DeepSpace.new(self, port, local_id)
      port.attach(deep_space.session)
#      uuid = session.peer_id unless uuid
      @deep_spaces[deep_space.peer_uuid] = deep_space
      puts "CONNECT DeepSpace: #{deep_space.peer_uuid}" if $DEBUG
      deep_space.connect
      deep_space
    end
    alias connect_deepspace_with_port connect_deep_space_with_port

    # client sesssion開始
    def open_deep_space(ipaddr, port)
      sock = TCPSocket.new(ipaddr, port)
      port = Port.new(sock)
      init_session_ev = Event::InitSessionEvent.new(local_id)
      port.export init_session_ev
      connect_deep_space_with_port(port)
    end
    alias open_deepspace open_deep_space

    # naming
    def register_service(name, obj)
      @naming[name] = obj
    end
    alias export register_service

    def service(name)
      @naming[name]
    end
    alias import service

    def id2obj(id)
      for peer_id, s in @deep_spaces
	if o = s.root(id)
	  return o
	end
      end
      raise "登録されていません.#{id}"
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

    @CLASS_SPEC_SPACE = ClassSpecSpace.new(:local)
    
    extend SingleForwardable

    def_delegator :@CLASS_SPEC_SPACE, :class_specs
    def_delegator :@CLASS_SPEC_SPACE, :def_method_spec
    def_delegator :@CLASS_SPEC_SPACE, :def_single_method_spec
    def_delegator :@CLASS_SPEC_SPACE, :method_spec
    def_delegator :@CLASS_SPEC_SPACE, :class_spec_id_of

    def_method_spec(Exception, "VAL backtrace()")
    def_method_spec(Exception, "REF set_backtrace(VAL)")

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
