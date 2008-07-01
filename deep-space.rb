#
#   session.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

require "thread"
require "weakref"

require "ipaddr"

require "deep-connect/session"

module DeepConnect
  class DeepSpace

    def initialize(org, port, local_id = nil)
      @organizer = org

      @session = Session.new(self, port, local_id)

      unless local_id
	local_id = port.peeraddr[1]
      end

      addr = port.peeraddr[3]
      ipaddr = IPAddr.new(addr)
      ipaddr = ipaddr.ipv4_mapped if ipaddr.ipv4?
      @peer_uuid = [ipaddr.to_s, local_id]

      # exportしているオブジェクト
      @export_roots = {}

      # importしているオブジェクト
      @import_reference = {}
    end

    attr_reader :organizer
    attr_reader :session
    attr_reader :peer_uuid
    alias peer_id peer_uuid

    def connect
      @session.start
    end

    def set_root(root)
      @export_roots[root.object_id] = root
      root.object_id
    end
    alias set_export_root set_root
    
    def root(id)
      @export_roots[id]
    end
    alias export_root root

    def register_root_from_other_session(id)
      @export_roots[id] = @organizer.id2obj(id)
    end

    def delete_root(id)
      @export_roots.delete(id)
    end

    def import_reference(id)
      if wr = @import_reference[id]
	wr.__getobj__
      else
	nil
      end
    end

    def register_import_reference(v)
      @import_reference[v.peer_id] = WeakRef.new(v)
      ObjectSpace.define_finalizer(v, deregister_import_reference_proc)
    end

    def deregister_import_reference_proc
      proc do |id|
	@import_reference.delete(id)
	deregister_root_to_peer(id)
      end
    end

    def get_service(name)
      @session.get_service(name)
    end
    alias import get_service

    def register_root_to_peer(id)
      @session.register_root_to_peer(id)
    end

    def deregister_root_to_peer(id)
      @session.deregister_root_to_peer(id)
    end
    
  end
end

