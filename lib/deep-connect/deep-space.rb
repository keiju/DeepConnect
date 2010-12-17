# encoding: UTF-8
#
#   deep-space.rb - 
#   	Copyright (C) 1996-2010 Keiju ISHITSUKA
#				(Penta Advanced Labrabries, Co.,Ltd)
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
#      ipaddr = ipaddr.ipv4_mapped if ipaddr.ipv4?
      ipaddr = ipaddr.native

      @peer_uuid = [ipaddr.to_s, local_id]

      init_front_feature
      init_class_spec_feature
      init_export_feature
      init_import_feature
    end

    def init_front_feature
      @front = Module.new
      @front.extend Front
      @front.backend = self
      @front
    end

    attr_reader :front

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
      end
      @session.stop

      @deregister_reference_thread.exit if org_status == :SERVICING
      @import_reference = nil
      @export_roots = nil
    end

    def import(name, waitp = false)
      @session.get_service(name, waitp)
    end
    alias get_service import 

    def import_mq(name, waitp = false)
      sv = @session.import_mq(name, waitp)
      DeepMQ::CL.new(sv)
    end
    alias get_mq import_mq

    #
    # class reference feature
    #
    def class_reference(peer_id)
      return nil unless peer_id
	
      if klass = import_reference(peer_id)
	return klass 
      end

      attr = @session.get_module_attr(peer_id)
      name = attr.shift
      csid = attr.shift
      rsuperclass = class_reference(attr.shift)
      rmodules = attr.collect{|id| module_reference(id)}
      ClassReference.create(self, name, csid, peer_id, rsuperclass, rmodules)
    end

    def module_reference(peer_id)
      return nil unless peer_id

      if mod = import_reference(peer_id)
	return mod
      end

      attr = @session.get_module_attr(peer_id)	
      name = attr.shift
      csid = attr.shift
      rmodules = attr.collect{|id| module_reference(id)}
      ModuleReference.create(self, name, csid, peer_id, rmodules)
    end

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
      @export_roots_mutex = Mutex.new
      @export_roots = {}
    end

    def release_object(obj)
      @export_roots_mutex.synchronize do
	@export_roots.delete(obj.object_id)
      end
    end

    def set_root(root)
#if root.kind_of?(Proc)
#  puts "SET_ROOT: #{root}\n #{caller(0)}"
#end
      @export_roots_mutex.synchronize do
	if pair = @export_roots[root.object_id]
	  pair[1] += 1
	else
	  @export_roots[root.object_id] = [root, 1]
	end
	root.object_id
      end
    end
    alias set_export_root set_root
    
    def root(id)
      @export_roots_mutex.synchronize do
	pair = @export_roots.fetch(id){return IllegalObject.new(id)}
	pair.first
	#@export_roots.fetch(id){:__DEEPCONNECT_NO_VALUE__}
      end
    end
    alias export_root root

    def register_root_from_other_session(id)
      obj = @organizer.id2obj(id)
      @export_roots_mutex.synchronize do
	if pair = @export_roots[id]
	  pair[1] += 1
	else
	  @export_roots[id] = [obj, 1]
	end
      end
      obj
    end

    def delete_roots(pairs)
      @export_roots_mutex.synchronize do
	pairs.each_slice(2) do |id, refcount|
	  if pair = @export_roots[id]
#	    puts "#{$$}: GC: #{id} #{refcount} #{pair.first.class} #{pair.last}"

	    if (pair[1] -= refcount) == 0
	      obj = @export_roots.delete(id)
	      if Conf.DISPLAY_GC
		puts "#{$$}: GC: delete root: #{id} #{obj.first.to_s}"
	      end
	    else
	      if Conf.DISPLAY_GC
		puts "#{$$}: GC: derefcount root: #{id} #{pair.first.to_s} #{pair[1]}"
		if pair.first.kind_of?(Exception)
		  p pair.first
		  p pair.first.backtrace
		end
	      end
	    end
	  else
	    if Conf.DISPLAY_GC
	      puts "#{$$}: GC: warn already deleted root: #{id.inspect}"
	    end
	  end
	end
      end
    end

    #
    # import 関連メソッド
    #
    def init_import_feature
      # importしているオブジェクト
      # peer_id => ref_id
      @import_reference = {}
      @rev_import_reference = {}

      @import_reference_mutex = Mutex.new
      @import_reference_cv = ConditionVariable.new
      @deregister_reference_queue = []

      @deregister_thread = nil
    end

    def import_reference(peer_id)
      return import_reference_for_disable_gc(peer_id) unless Conf.ENABLE_GC

      status = GC.disable
      begin
	@import_reference_mutex.synchronize do
	  if pair = @import_reference[peer_id]
	    begin
	      ObjectSpace._id2ref(pair.first)
	    rescue
	      ref_id = @import_reference.delete(peer_id)
	      @rev_import_reference.delete(ref_id)
	      @deregister_reference_queue.concat [peer_id, 1]
	      return nil
	    end
	  else
	    nil
	  end
	end
      ensure
	GC.enable unless status
      end
    end

    def import_reference_for_disable_gc(peer_id)
      @import_reference_mutex.synchronize do
	if pair = @import_reference[peer_id]
	  pair.first
	else
	  nil
	end
      end
    end

    def register_import_reference(ref)
      return register_import_reference_for_disable_gc(ref) unless Conf.ENABLE_GC

      status = GC.disable
      begin
	@import_reference_mutex.synchronize do
	  if pair = @import_reference[ref.peer_id]
	    pair[1] += 1
	  else
	    @import_reference[ref.peer_id] = [ref.object_id, 1]
	    @rev_import_reference[ref.object_id] = ref.peer_id
	  end
	end
	ObjectSpace.define_finalizer(ref, deregister_import_reference_proc)
      ensure
	GC.enable unless status
      end
    end

    def register_import_reference_for_disable_gc(ref)
      @import_reference_mutex.synchronize do
	if pair = @import_reference[ref.peer_id]
	  pair[1] += 1
	else
	  @import_reference[ref.peer_id] = [ref, 1]
	end
      end
    end

    def deregister_import_reference(ref)
      return deregister_import_reference_for_disable_gc(ref) unless Conf.ENABLE_GC
      status = GC.disable
      begin
	@import_reference_mutex.synchronize do
	  pair = @import_reference.delete(ref.peer_id)
	  @rev_import_reference.delete(pair.first)
	  @deregister_reference_queue.concat [ref.peer_id, pair.last]
	end
      ensure
	GC.enable unless status
	@deregister_thread.wakeup
      end
    end

    def deregister_import_reference_for_disable_gc(ref)
      status = GC.disable
      begin
	@import_reference_mutex.synchronize do
	  pair = @import_reference.delete(ref.peer_id)
	  @deregister_reference_queue.concat [ref.peer_id, pair.last]
	end
      ensure
	GC.enable unless status
	@deregister_thread.wakeup
      end
    end
 
    def deregister_import_reference_proc
      proc do |ref_id|
	if @status == :SERVICING
	  puts "#{$$}: GC: gced id: #{ref_id}" if Conf.DISPLAY_GC
	  peer_id = @rev_import_reference.delete(ref_id)
	  pair = @import_reference.delete(peer_id)
	  @deregister_reference_queue.concat [peer_id, pair.last]
	  @deregister_thread.wakeup
	end
      end
    end

    def start_deregister_reference_org
      @deregister_thread  = Thread.start {
	ids = []
	while ids.push @deregister_reference_queue.pop
	  begin
	    while ids.push @deregister_reference_queue.pop(true); end
	  rescue ThreadError
	    deregister_roots_to_peer(ids) if @status == :SERVICING
	  end
	end
      }
    end

    def start_deregister_reference
      @deregister_thread  = Thread.start {
	ids = []
	loop do
	  Thread.stop
	  Thread.exit unless @status == :SERVICING

	  ids = []
	  @import_reference_mutex.synchronize do
	    status = GC.disable
	    begin
	      ids = @deregister_reference_queue.dup
	      @deregister_reference_queue.clear
	    ensure
	      GC.enable unless status
	    end
	  end
	  unless ids.empty?
	    deregister_roots_to_peer(ids) 
	  end
	  sleep 1
	end
      }
    end

    def register_root_to_peer(id)
      unless import_reference(id)
	@session.register_root_to_peer(id)
      end
    end

    def deregister_roots_to_peer(ids)
      puts "#{$$}: GC: send deregister id: #{ids.join(' ')}" if Conf.DISPLAY_GC
      @session.deregister_root_to_peer(ids)
    end

    module Front
      extend Forwardable
      attr_accessor :backend

      def_delegator :@backend, :close
      def_delegator :@backend, :import
      alias get_service :import

      def const_missing(name)
	@backend.import(name)
      end
    end
  end

  class DeepSpaceNoConnection
    def initialize(peer_id)
      @peer_id = peer_id
    end

    attr_reader :peer_id
    alias peer_uuid peer_id

    def session
      DC::Raise ConnectionRefused, @peer_id
    end
    def register_import_reference(r)
      nil
    end

    def import_reference(r)
      nil
    end

    def register_root_to_peer(object_id)
      # do nothing
    end
    
  end

  class IllegalObject
    def initialize(id)
      @id = id
    end

    def send(*opts)
      DC.Raise IllegalReference, @id, opts.first
    end
# Ruby has warned from version 1.9.2.
#    alias __send__ send
#    alias __public_send__ send
  end
end

