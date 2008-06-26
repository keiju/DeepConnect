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

require "deep-connect/accepter"
require "deep-connect/evaluator"
require "deep-connect/session"
require "deep-connect/port"
require "deep-connect/event"

trap("SIGPIPE", "IGNORE")

module DeepConnect
  class Organizer
    def initialize
      @accepter = Accepter.new(self)
      @sessions = {}
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
      @local_id_mutex.syncronize do
	while !@local_id
	  @local_id_cv.wait(@local_id_mutex)
	end
      end
      @local_id
    end
    attr_reader :local_id

    def start(service)
      @accepter.open(service)
      @local_id = @accepter.port_number
      @local_id_cv.broadcast

      @accepter.start
    end

    def stop
      @accepter.close
    end

    def session(peer_id, &block)
      if session = @sessions[peer_id]
	return session
      end

      # セッションを自動的に開く
      session = open_session(*peer_id)
      block.call session 
      session
    end

    # session登録
    def register_session_on_port(port, local_id = nil)
      session = Session.new(self, port, local_id)
      port.attach(session)
#      uuid = session.peer_id unless uuid
      @sessions[session.peer_uuid] = session
      puts "CONNECT SESSION: #{session.peer_uuid}" if $DEBUG
      session.start
    end

    # client sesssion開始
    def open_session(ipaddr, port)
      sock = TCPSocket.new(ipaddr, port)
      port = Port.new(sock)
      init_session_ev = Event::InitSessionEvent.new(local_id)
      port.export init_session_ev
      register_session_on_port(port)
    end

    # naming
    def register_service(name, obj)
      @naming[name] = obj
    end

    def service(name)
      @naming[name]
    end

    def id2obj(id)
      for peer_id, s in @sessions
	if o = s.root(id)
	  return o
	end
      end
    end
  end
end


