#!/usr/local/bin/ruby
#
#   packet.rb - 
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

  module Event
    def Event.materialize(sm, type, *rest)
      type.send("materialize_sub", sm, type, *rest)
    end

    class Event
      def initialize(receiver)
	@receiver = receiver
      end
      
      attr :receiver
      attr :seq
    
      public :iterator?
    end

    class Request < Event
      SEQ = [0]
    
      def Request.request(receiver, method, *args)
	req = new(receiver, method, *args)
	req.init_req
	req
      end
      
      def Request.receipt(seq, receiver, method, *args)
	rec = new(receiver, method, *args)
	rec.set_seq(seq)
	rec
      end
    
      def Request.materialize_sub(sm, type, seq, receiver, method, *args)
	type.receipt(seq,
		     sm.root(receiver),
		     method,
		     *args.collect{|elm| Reference.materialize(sm, *elm)})
      end
    
      def initialize(receiver, method, *args)
	super(receiver)
	@method = method
	@args = args
      end
    
      def init_req
	@seq = SEQ[0] += 1
	@results = Queue.new
      end
    
      def set_seq(seq)
	@seq = seq
      end
    
      def apply_on(sm)
	Thread.start do
	  print "apply_on: ", self.inspect, "\n"
	  ret = @receiver.send(@method, *@args)
	  sm.req Reply.new(@seq, @receiver, ret).serialize(sm)
	end
      end
    
      def serialize(sm)
	[type, @seq, @receiver.peer_id, @method].concat(@args)
      end
    
      def request?
	TRUE
      end
    
      def iterator?
	FALSE
      end
    
      def result(*ret)
	if ret.size == 0
	  @results.pop
	else
	  @results.push *ret
	end
      end
    
      attr :method
      attr :args
    end

    class IteratorRequest < Request
      def apply_on(sm)
	Thread.start do
	  #      print "apply_on: ", self.inspect
	  @receiver.send(@method, *@args) do
	    |ret|
	    sm.req IteratorReply.new(@seq, @receiver, ret).serialize(sm)
	  end
	  sm.req IteratorReply.new(@seq, @receiver, :finish).serialize(sm)
	end
      end
    
      def iterator?
	TRUE
      end
    
      def results(*ret)
	if ret.empty?
	  while (ret = @results.pop) != :finish
	    yield ret
	  end
	else
	  @results.push *ret
	end
      end
    end

    class Reply < Event
      def Reply.materialize_sub(sm, type, seq, receiver, ret)
	type.new(seq, sm.root(receiver), Reference.materialize(sm, *ret))
      end
    
      def initialize(seq, receiver, ret)
	super(receiver)
	@seq = seq
	@result = ret
      end
    
      def serialize(sm)
	[type, @seq, 
	  Reference.serialize(sm, @receiver),
	  Reference.serialize(sm, @result)]
      end
    
      def request?
	FALSE
      end
    
      def iterator?
	FALSE
      end
    
      attr :result
    end

    class IteratorReply < Reply
      def iterator?
	TRUE
      end
    
      def finish?
	@result == :finish
      end
    end
  end
end
