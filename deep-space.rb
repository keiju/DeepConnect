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

      init_class_spec_feature
      init_export_feature
      init_import_feature
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

      @deregister_reference_thread = start_deregister_reference

      @status = :SERVICING
    end

    def disconnect(*opts)
      org_status = @status
      @status = :SERVICE_STOP
      
      @session.stop_service(*opts)
      if !opts.include?(:SESSION_CLOSED) && !opts.include?(:REQUEST_FROM_PEER)
	@session.send_disconnect
	@session.stop
      end

      @deregister_reference_thread.exit if org_status == :SERVICING
      @import_reference = nil
      @export_roots = nil
    end

    def import(name)
      @session.get_service(name)
    end
    alias get_service import 

    #
    # class spec feature
    #
    def init_class_spec_feature
      # class spec
      @class_spec_space = ClassSpecSpace.new(:remote)
    end

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
    def init_export_feature
      # exportしているオブジェクト
      @export_roots = {}
    end

    def release_object(obj)
      @export_roots.delete(obj.object_id)
    end

    def set_root(root)
      @export_roots[root.object_id] = root
      root.object_id
    end
    alias set_export_root set_root
    
    def root(id)
      @export_roots.fetch(id){IllegalObject.new}
    end
    alias export_root root

    def register_root_from_other_session(id)
      @export_roots[id] = @organizer.id2obj(id)
    end

    def delete_roots(ids)
      puts "GC: delete root: #{ids.join(' ')}" if DISPLAY_GC
      for id in ids
	@export_roots.delete(id)
      end
    end

    #
    # import 関連メソッド
    #
    def init_import_feature
      # importしているオブジェクト
      @import_reference = {}
      @import_reference_mutex = Mutex.new
      @deregister_reference_queue = Queue.new
    end

    def import_reference(id)
      if @import_reference[id]
	begin
	  ObjectSpace._id2ref(@import_reference[id])
	rescue
	  @import_reference.delete(id)
	  nil
	end
      else
	nil
      end
    end

    def register_import_reference(v)
      @import_reference_mutex.synchronize do
	@import_reference[v.peer_id] = v.object_id
      end
      ObjectSpace.define_finalizer(v, deregister_import_reference_proc)
    end

    def deregister_import_reference_id(rid)
      @import_reference_mutex.synchronize do
	@import_reference.delete(rid)
      end
      @deregister_reference_queue.push rid
    end

    def deregister_import_reference_proc
      proc do |id|
	if @status == :SERVICING
	  puts "GC: gced id: #{id}" if DISPLAY_GC
	  @import_reference.delete(id)
	  @deregister_reference_queue.push id
	end
      end
    end

    def start_deregister_reference
      Thread.start do
	ids = []
	while ids.push @deregister_reference_queue.pop
	  begin
	    while ids.push @deregister_reference_queue.pop(true); end
	  rescue ThreadError
	    deregister_roots_to_peer(ids) if @status == :SERVICING
	  end
	end
      end
    end

    def register_root_to_peer(id)
      @session.register_root_to_peer(id)
    end

    def deregister_roots_to_peer(ids)
      puts "GC: send deregister id: #{ids.join(' ')}" if DISPLAY_GC
      @session.deregister_root_to_peer(ids)
    end
    
  end

  class IllegalObject
    def send(*opts)
      DC.Raise IllegalReference
    end
    alias __send__ send
    alias __public_send__ send
  end
end

