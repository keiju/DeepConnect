#
#   deep-space.rb - 
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
require "forwardable"

require "ipaddr"

require "deep-connect/session"
require "deep-connect/class-spec-space"

module DeepConnect
  class DeepSpace
    extend Forwardable

    def initialize(org, port, local_id = nil)
      @status = :INITIALIZE

      @organizer = org
      @session = Session.new(self, port, local_id)

      unless local_id
	local_id = port.peeraddr[1]
      end

      addr = port.peeraddr[3]
      ipaddr = IPAddr.new(addr)
      ipaddr = ipaddr.ipv4_mapped if ipaddr.ipv4?
      @peer_uuid = [ipaddr.to_s, local_id]

      # class spec
      @class_spec_space = ClassSpecSpace.new(:remote)

      # exportしているオブジェクト
      @export_roots = {}

      # importしているオブジェクト
      @import_reference = {}
    end

    attr_reader :status
    attr_reader :organizer
    attr_reader :session
    attr_reader :peer_uuid
    alias peer_id peer_uuid

    def close
      @organizer.close_deepspace(self)
    end

    def connect
      @session.start
      @status = :SERVICING
    end

    def disconnect(*opts)
      @status = :SERVICE_STOP
      
      @session.stop_service(*opts)
      if !opts.include?(:SESSION_CLOSED) && !opts.include?(:REQUEST_FROM_PEER)
	@session.send_disconnect
	@session.stop
      end

      @import_reference = nil
      @export_roots = nil
    end

    #  接続時に転送する
    def_delegator :@class_spec_space, :class_specs=
    def_delegator :@class_spec_space, :method_spec
    def_delegator :@class_spec_space, :class_spec_id_of
    alias csid_of class_spec_id_of
    
    def my_method_spec(obj, method)
      Organizer::method_spec(obj, method)
    end

    def my_csid_of(obj)
      Organizer::class_spec_id_of(obj)
    end

    def recv_class_spec(cspecs)
      cspecs.each{|cspec| add_class_spec(cspec)}
      make_class_spec_cache(cspecs.first)
    end

    def make_class_spec_cache(cspec)
      cache = ClassSpec.new
      
    end

    #
    # export root 関連メソッド
    #
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

    #
    # import 関連メソッド
    #
    def import_reference(id)
      if wr = @import_reference[id]
	begin
	  wr.__getobj__
	rescue
	  @import_reference.delete(id)
	  nil
	end
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
	if @status == :SERVICING
	  @import_reference.delete(id)
	  deregister_root_to_peer(id)
	end
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

