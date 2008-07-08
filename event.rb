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

require "deep-connect/method-spec"
require "deep-connect/reference"

module DeepConnect

  class PeerSideException<StandardError
    def initialize(exp)
      super(exp.message)
      @peer_exception = exp
    end

#     def backtrace
#       bt = @peer_exception.backtrace.to_a
# #p bt
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
      
      attr_reader :session
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
    
      def Request.materialize_sub(session, type, klass, seq, receiver_id, method, *args)
	receiver = session.deep_space.root(receiver_id)

	type.receipt(session, seq,
		     receiver,
		     method,
		     *args.collect{|elm| 
		       Reference.materialize(session.deep_space, *elm)})
      end

      def reply(ret, exp = nil, reply_class = reply_class)
	  
	reply_class.reply(self.session, self, ret, exp)
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
	mspec = @session.deep_space.method_spec(@receiver, @method)
	if mspec && mspec.args
	  args = mspec.arg_zip(@args){|spec, arg|
	    Reference.serialize_with_spec(@session.deep_space, arg, spec)
	  }
	else
	  args = @args.collect{|elm| 
	    Reference.serialize(@session.deep_space, elm)
	  }
	end
#	@receiver.peer_id
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
 	    bt = ev.exp.backtrace.to_a
 	    bt.push "-- peer side --"
 	    bt.push *caller(0)
 	    bt = bt.select{|e| /deep-connect/ !~ e}
	    
 	    raise PeerSideException, ev.exp, bt
#	    raise PeerSideException.new(ev.exp)
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
      def initialize(*opts)
	super
	@call_back = Queue.new
      end
      
      def reply_class
	IteratorReply
      end
    
      def iterator?
	TRUE
      end
    
#       def results(*ret, &block)
# 	if ret.empty?
# 	  while !(ret = @results.pop).kind_of?(IteratorReplyFinish)
# 	    block.call *ret.result
# #	    yield ret.result
# 	  end
# 	  ret.result
# 	else
# 	  @results.push *ret
# 	end
#       end

      def call_back(&block)
	while !(ret = @call_back.pop).kind_of?(IteratorCallBackRequestFinish)
	  block.call ret
	end
      end

      def push_call_back(ev)
	@call_back.push ev
      end
    end

    class IteratorCallBackRequest<Request

      def IteratorCallBackRequest.materialize_sub(session, type, klass, seq, receiver_id, method, *args)
	type.receipt(session, seq,
		     Reference.materialize(session.deep_space, *receiver_id),
		     method,
		     *args.collect{|elm| 
		       Reference.materialize(session.deep_space, *elm)})
      end

      def IteratorCallBackRequest.call_back_event(event, *args)
	req = new(event.session, event.receiver, event.method, *args)
	req.init_req
	req.set_seq([req.seq, event.seq])
	req
      end

      def reply_class
	IteratorCallBackReply
      end

      def serialize
	mspec = @session.deep_space.my_method_spec(@receiver, @method)
	if mspec && mspec.block_args
	  args = mspec.block_arg_zip(@args){|spec, arg|
	    Reference.serialize_with_spec(@session.deep_space, arg, spec)
	  }
	else
	  args = @args.collect{|elm| 
	    Reference.serialize(@session.deep_space, elm)
	  }
	end
	[self.class, @seq,  
	  Reference.serialize(@session.deep_space, @receiver),
	  method].concat(args)
      end


      def iterator?
	true
      end
    end
    
    class IteratorCallBackRequestFinish<IteratorCallBackRequest
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
    
      def serialize
	args = @args.collect{|elm| 
	  Reference.serialize(@session.deep_space, elm)
	}
	[self.class, @seq, @receiver.peer_id, @method].concat(args)
      end

      def inspect
	sprintf "#<#{self.class}, session=#{@session}, seq=#{@seq}, method=#{@method.id2name}, args=#{@args.collect{|e| e.to_s}.join(', ')}>"
      end
    end

    class SessionRequestNoReply<SessionRequest
      include NoReply
    end

    class Reply < Event
      def Reply.materialize_sub(session, type, klass, seq, receiver, method, ret, exp=nil)
	if exp
	  type.new(session, seq, 
		   session.deep_space.root(receiver), 
		   method,
		   Reference.materialize(session.deep_space, *ret),
		   Reference.materialize(session.deep_space, *exp))
	else
	  type.new(session, seq, 
		   session.deep_space.root(receiver), 
		   method,
		   Reference.materialize(session.deep_space, *ret))

	end
      end

      def self.reply(session, req, ret, exp=nil)
	new(session, req.seq, req.receiver, req.method, ret, exp)
      end
    
      def initialize(session, seq, receiver, method, ret, exp=nil)
	super(session, receiver)
	@seq = seq
	@method = method
	@result = ret
	@exp = exp
      end
    
      def serialize
	mspec = @session.deep_space.my_method_spec(@receiver, @method)
	if mspec && mspec.rets
	  if mspec.rets.kind_of?(Array)
	    rets = mspec.rets_zip(@result){|spec, ret|
	      Reference.serialize_with_spec(@session.deep_space, ret, spec)
	    }
	    sel_result = [:VAL, "Array", [Array, rets]]
	  else
	    sel_result = Reference.serialize(@session.deep_space, @result, mspec.rets)
	  end
	else
	  sel_result = Reference.serialize(@session.deep_space, @result)
	end
	
	if @exp
	  [self.class, @seq, 
	    Reference.serialize(@session.deep_space, @receiver),
	    @method,
	    sel_result,
	    Reference.serialize(@session.deep_space, @exp)]
	else
	  [self.class, @seq, 
	    Reference.serialize(@session.deep_space, @receiver),
	    @method,
	    sel_result]
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
	sprintf "#<#{self.class}, session=#{@session}, seq=#{@seq}, receiver=#{@receiver}, method=#{@method} result=#{@result}}>"
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

    class IteratorCallBackReply<Reply
      def serialize
	mspec = @session.deep_space.method_spec(@receiver, @method)
	if mspec && mspec.rets
	  if mspec.rets.kind_of?(Array)
	    rets = mspec.rets_zip(@result){|spec, ret|
	      Reference.serialize_with_spec(@session.deep_space, ret, spec)
	    }
	    sel_result = [:VAL, "Array", [Array, rets]]
	  else
	    sel_result = Reference.serialize(@session.deep_space, @result, mspec.rets)
	  end
	else
	  sel_result = Reference.serialize(@session.deep_space, @result)
	end
	
	if @exp
	  [self.class, @seq, 
	    Reference.serialize(@session.deep_space, @receiver),
	    @method,
	    sel_result,
	    Reference.serialize(@session.deep_space, @exp)]
	else
	  [self.class, @seq, 
	    Reference.serialize(@session.deep_space, @receiver),
	    @method,
	    sel_result]
	end
      end

      def iterator?
	true
      end
    end

    class IteratorCallBackReplyBreak<IteratorCallBackReply
      def iterator?
	true
      end
    end


    class IteratorReplyFinish < Reply
      def iterator?
	true
      end
    
      def finish?
	true
      end
    end

    class SessionReply < Reply
      def SessionReply.materialize_sub(session, type, klass, seq, receiver, method, ret)
#	puts "SESSIONREPLY: #{type}, #{session}, #{ret.collect{|e| e.to_s}.join(',')}"	
	type.new(session, seq, 
		 session, 
		 method,
		 Reference.materialize(session.deep_space, *ret))
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


