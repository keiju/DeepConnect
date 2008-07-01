#!/usr/local/bin/ruby
#
#   event.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

require "deep-connect/reference"

module DeepConnect

  class PeerSideException<StandardError
    def initialize(exp)
      super(exp.message)
      @peer_exception = exp
    end

#     def backtrace
# #      bt = @peer_exception.backtrace.to_a
# #      bt.push *super
#       bt
#     end
    
    attr_reader :peer_exception
  end

  module Event
    def Event.materialize(session, type, *rest)
      type.materialize_sub(session, type, *rest)
    end

    class Event
      def initialize(session, receiver)
	@session = session
	@receiver = receiver
      end
      
      attr :receiver
      attr :seq
    
      public :iterator?

      def inspect
	sprintf "#<#{self.class}, session=#{@session}, seq=#{@seq}, receiver=#{@receiver}>"
      end
    end

    module NoReply; end

    class Request < Event
      def Request.request(session, receiver, method, *args)
	req = new(session, receiver, method, *args)
	req.init_req
	req
      end
      
      def Request.receipt(session, seq, receiver, method, *args)
	rec = new(session, receiver, method, *args)
	rec.set_seq(seq)
	rec
      end
    
      def Request.materialize_sub(session, type, klass, seq, receiver, method, *args)
	type.receipt(session, seq,
		     session.root(receiver),
		     method,
		     *args.collect{|elm| Reference.materialize(session, *elm)})
      end

      def reply_class
	Reply
      end
    
      def initialize(session, receiver, method, *args)
	super(session, receiver)
	@method = method
	@args = args
      end
    
      def init_req
	@seq = @session.next_request_event_id
	@results = Queue.new
      end
    
      def set_seq(seq)
	@seq = seq
      end
    
      def serialize
	args = @args.collect{|elm| Reference.serialize(@session, elm)}
	[self.class, @seq, @receiver.peer_id, @method].concat(args)
      end
    
      def request?
	TRUE
      end
    
      def iterator?
	FALSE
      end
    
      def result(*ret)
	if ret.size == 0
	  ev = @results.pop
	  if ev.exp
	    raise PeerSideException.new(ev.exp)
	  end
	  ev.result
	else
	  @results.push *ret
	end
      end
    
      attr :method
      attr :args

      def inspect
	sprintf "#<#{self.class}, session=#{@session}, seq=#{@seq}, receiver=#{@receiver}, method=#{@method.id2name}, args=#{@args.collect{|e| e.to_s}.join(', ')}>"
      end
    end

    class IteratorRequest < Request
      def reply_class
	IteratorReply
      end
    
      def iterator?
	TRUE
      end
    
      def results(*ret, &block)
	if ret.empty?
	  while !(ret = @results.pop).kind_of?(IteratorReplyFinish)
	    block.call ret.result
#	    yield ret.result
	  end
	  ret.result
	else
	  @results.push *ret
	end
      end
    end

    class IteratorSubRequest < Request
      def itr_id
	@args[0]
      end
    end

    class IteratorNextRequest<IteratorSubRequest; end
    class IteratorExitRequest<IteratorSubRequest; end
#    class IteratorRetryRequest<IteratorSubRequest; end

    class SessionRequest < Request
      def SessionRequest.request(session, method, *args)
	req = new(session, session, method, *args)
	req.init_req
	req
      end

      def SessionRequest.receipt(session, seq, dummy, method, *args)
	rec = new(session, session, method, *args)
	rec.set_seq(seq)
	rec
      end

      def reply_class
	SessionReply
      end
    
      def inspect
	sprintf "#<#{self.class}, session=#{@session}, seq=#{@seq}, method=#{@method.id2name}, args=#{@args.collect{|e| e.to_s}.join(', ')}>"
      end
    end

    class SessionRequestNoReply<SessionRequest
      include NoReply
    end

    class Reply < Event
      def Reply.materialize_sub(session, type, klass, seq, receiver, ret, exp=nil)
	if exp
	  type.new(session, seq, 
		   session.root(receiver), 
		   Reference.materialize(session, *ret),
		   Reference.materialize(session, *exp))
	else
	  type.new(session, seq, 
		   session.root(receiver), 
		   Reference.materialize(session, *ret))
	end
      end
    
      def initialize(session, seq, receiver, ret, exp=nil)
	super(session, receiver)
	@seq = seq
	@result = ret
	@exp = exp
      end
    
      def serialize
	if @exp
	  [self.class, @seq, 
	    Reference.serialize(@session, @receiver),
	    Reference.serialize(@session, @result),
	    Reference.serialize(@session, @exp)]
	else
	  [self.class, @seq, 
	    Reference.serialize(@session, @receiver),
	    Reference.serialize(@session, @result)]
	end
      end

      def request?
	false
      end
    
      def iterator?
	false
      end
    
      attr_reader :result
      attr_reader :exp

      def inspect
	sprintf "#<#{self.class}, session=#{@session}, seq=#{@seq}, receiver=#{@receiver}, result=#{@result}}>"
      end
    end

    class IteratorReply < Reply
      def iterator?
	true
      end
    
      def finish?
	false
      end
    end

    class IteratorReplyFinish < IteratorReply
      def iterator?
	true
      end
    
      def finish?
	true
      end
    end

    class SessionReply < Reply
      def SessionReply.materialize_sub(session, type, klass, seq, receiver, ret)
#	puts "SESSIONREPLY: #{type}, #{session}, #{ret.collect{|e| e.to_s}.join(',')}"	
	type.new(session, seq, 
		 session, 
		 Reference.materialize(session, *ret))
      end

      def inspect
	sprintf "#<#{self.class}, session=#{@session}, seq=#{@seq},  result=#{@result}}>"
      end
    end

    class InitSessionEvent<Event
      def self.materialize_sub(session, type, klass, local_id)
	new(local_id)
      end

      def initialize(local_id)
	@local_id=local_id
      end


      attr_reader :local_id

      def serialize
	[self.class, @local_id]
      end
    end
  end
end


