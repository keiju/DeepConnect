#!/usr/local/bin/ruby
#
#   controller.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Nihon Rational Software Co.,Ltd)
#
# --
#
#   
#

module DIST
  class Controller
    def Controller.start(name)
      sm = new(name)
      sm.start
    end

    # initializing
    def initialize(name)
      @name = name
      @waiting = Hash.new
      @waiting.extend Mutex_m
      
      @export_queue = Queue.new
      @import_queue = Queue.new
      
      @roots = Hash.new
    end
    
    # accessing
    attr :peer, TRUE
    
    def start
      @exporter = Thread.start{self.accept}
      @importer = Thread.start{self.reply}
      self
    end
    
    def accept
      loop do
	ev = @export_queue.pop
	print "Accept(#{@name})"  if $SYM
	#      print ev.inspect
	if ev.kind_of? Event::Event
	  @waiting.synchronize do
	    @waiting[ev.seq] = ev
	  end
	  @peer.recv(ev.serialize(self))
	else
	  @peer.recv(ev)
	end
      end
    end
    
    def reply
      loop do
	ev = @import_queue.pop
	#      print ev.join(" ")
	ev = Event.materialize(self, *ev)
	print "Reply(#{@name})" if $SYM
	if ev.request?
	  print "  Req" if $SYM
	  ev.apply_on(self)
	else
	  print "  Rep" if $SYM
	  req = nil
	  @waiting.synchronize do
	    if ev.iterator?
	      if ev.finish?
		req = @waiting.delete(ev.seq)
	      else
		req = @waiting[ev.seq]
	      end
	    else
	      req = @waiting.delete(ev.seq)
	    end
	  end
	  req.result ev.result
	end
      end
    end
    
    def recv(ev)
      @import_queue.push(ev)
    end
    
    def req(ev)
      @export_queue.push(ev)
    end
    
    def send_to(ref, method, *args)
      pxargs = args.collect{|elm| Reference.serialize(self, elm)}
      if iterator?
	ev = Event::IteratorRequest.request(ref, method, *pxargs)
	@export_queue.push ev
	ev.results do
	  |elm|
	  yield elm
	end
      else
	ev = Event::Request.request(ref, method, *pxargs)
	@export_queue.push ev
	ev.result
      end
    end
    
    def set_root(root)
      @roots[root.id] = root
      root.id
    end
    
    def root(id)
      @roots[id]
    end
  end
end
