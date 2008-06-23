#
#   organizer.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#  UC1: サーバ起動
#  UC2: クライアント接続
#  UC3: クライアント接続要求
#
#   
#

require "deep-connect/accepter"
require "deep-connect/evaluator"
require "deep-connect/session"
require "deep-connect/port"

trap("SIGPIPE", "IGNORE")

module DeepConnect
  class Organizer
    def initialize
      @accepter = Accepter.new(self)
      @sessions = {}
      @evaluator = Evaluator.new(self)
#      @naming = Naming.new
      @naming = {}
    end

    attr_reader :accepter
    attr_reader :evaluator
#    attr_reader :naming

    def start(service)
      @accepter.open(service)
      @accepter.start
    end

    def stop
      @accepter.close
    end

    def session(peer_id)
      @sessions[peer_id]
    end

    # session登録
    def register_session_on_port(port)
      session = Session.new(self, port)
      port.attach(session)
      @sessions[session.peer_id] = session
      p session.peer_id if $DEBUG
      session.start
    end

    # client sesssion開始
    def open_session(ipaddr, port)
      sock = TCPSocket.new(ipaddr, port)
      port = Port.new(sock)
      register_session_on_port(port)
    end

    # naming
    def register_service(name, obj)
      @naming[name] = obj
    end

    def service(name)
      @naming[name]
    end

  end
end


