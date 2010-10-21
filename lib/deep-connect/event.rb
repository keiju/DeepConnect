# encoding: UTF-8
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

require "deep-connect/class-spec-space"
require "deep-connect/reference"

module DeepConnect

  class PeerSideException<StandardError
    def initialize(exp)
#Fairy::Log.debug(self, exp.inspect)
      begin 
	m = exp.message
      rescue
	m = "(NoMessage from PeerSide)"
      end
      super(m)
      @peer_exception = exp
    end

    attr_reader :peer_exception
  end

  module Event
    EV = Event

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
      def Request.request(session, receiver, method, args)
	req = new(session, receiver, method, args)
	req.init_req
	req
      end
      
      def Request.receipt(session, seq, receiver, method, args)
	rec = new(session, receiver, method, args)
	rec.set_seq(seq)
	rec
      end
      
      def Request.materialize_sub(session, type, klass, seq, receiver_id, method, args)
	receiver = session.deep_space.root(receiver_id)

	type.receipt(session, seq,
		     receiver,
		     method,
		     args.collect{|elm| 
		       Reference.materialize(session.deep_space, *elm)})
      end

      def reply(ret, exp = nil, reply_class = reply_class)
	reply_class.reply(self.session, self, ret, exp)
      end

      def reply_class
	Reply
      end
      
      def initialize(session, receiver, method, args)
	super(session, receiver)
	@method = method
	@args = args
      end
      
      def init_req
	@seq = @session.next_request_event_id
	@result = :__DEEPCONNECT__NO_VALUE__
	@result_mutex = Mutex.new
	@result_cv = ConditionVariable.new
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
	sel = [self.class, @seq, @receiver.peer_id, @method]
	sel.push args
	sel
      end
      
      def request?
	true
      end

      def result_event
	@result_mutex.synchronize do
	  while @result == :__DEEPCONNECT__NO_VALUE__
	    @result_cv.wait(@result_mutex)
	  end
	end
	@result
      end
      
      def result
	result_event
	if @result.exp
	  raise create_exception
	end
	@result.result
      end
      
      def result=(ev)
	@result = ev
	@result_cv.broadcast
      end

      attr :method
      attr :args

      def inspect
	sprintf "#<#{self.class}, session=#{@session}, seq=#{@seq}, receiver=#{@receiver}, method=#{@method.id2name}, args=#{@args.collect{|e| e.to_s}.join(', ')}>"
      end

      def create_exception
	exp = nil
	begin
	  exp = @result.exp.dc_dup
	rescue
	  exp = PeerSideException.new(@result.exp)
	end

	bt = @result.exp.backtrace
	bt.push "-- peer side --"
	bt.push *caller(0)
	bt = bt.select{|e| /deep-connect/ !~ e} unless DC::DEBUG
	exp.set_backtrace(bt)
	exp
      end

    end

    class RequestWithBlock < Request
      def self.materialize_sub(session, type, klass, seq, receiver_id, method, args, block)

	receiver = receiver(session, receiver_id)

	type.receipt(session, seq,
		     receiver,
		     method,
		     args.collect{|elm| 
		       Reference.materialize(session.deep_space, *elm)},
		     Reference.materialize(session.deep_space, *block))
      end

      def self.request(session, receiver, method, args, block)
	req = new(session, receiver, method, args, block)
	req.init_req
	req
      end
      
      def self.receipt(session, seq, receiver, method, args, block)
	rec = new(session, receiver, method, args, block)
	rec.set_seq(seq)
	rec
      end

      def initialize(session, receiver, method, args, block)
	super(session, receiver, method, args)
	@block = block
      end

      attr_reader :block

      def serialize
	mspec = method_spec(@receiver, @method)
	if mspec && mspec_args(mspec)
	  args = mspec_arg_zip(mspec){|spec, arg|
	    Reference.serialize_with_spec(@session.deep_space, arg, spec)
	  }
	else
	  args = @args.collect{|elm| 
	    Reference.serialize(@session.deep_space, elm)
	  }
	end
	receiver_id = receiver_id(@receiver)
	#	@receiver.peer_id
	sel = [self.class, @seq, receiver_id, @method]
	sel.push args
	sel.push Reference.serialize(@session.deep_space, @block)
	sel
      end
    end

    class IteratorRequest<RequestWithBlock

      def self.receiver(session, receiver_id)
	session.deep_space.root(receiver_id)
      end

      def method_spec(receiver, method)
	@session.deep_space.method_spec(receiver, method)
      end

      def receiver_id(receriver)
	receiver.peer_id
      end

      def mspec_args(mspec)
	mspec.args
      end

      def mspec_arg_zip(mspec, &block)
	mspec.arg_zip(@args, &block)
      end

      def reply_class
	IteratorReply
      end
    end
    
    class IteratorCallBackRequest<RequestWithBlock

      def self.receiver(session, receiver_id)
	Reference.materialize(session.deep_space, *receiver_id)
      end

      def method_spec(receiver, method)
	@session.deep_space.my_method_spec(receiver, method)
      end

      def receiver_id(receriver)
	Reference.serialize(@session.deep_space, @receiver)
      end

      def mspec_args(mspec)
	mspec.block_args
      end

      def mspec_arg_zip(mspec, &block)
	mspec.block_arg_zip(@args, &block)
      end

      def IteratorCallBackRequest.call_back_event(event, args)
	req = new(event.session, event.receiver, event.method, args, event.block)
	req.init_req
	req
      end

      def reply_class
	IteratorCallBackReply
      end
    end

    class AsyncronusRequest<Request
      def AsyncronusRequest.request(session, receiver, method, args, callback)
	req = new(session, receiver, method, args, callback)
	req.init_req
	req
      end

      def AsyncronusRequest.receipt(session, seq, receiver, method, args)
	rec = new(session, receiver, method, args)
	rec.set_seq(seq)
	rec
      end


      def initialize(session, receiver, method, args, callback = nil)
	super(session, receiver, method, args)
	@callback = callback
      end

      def reply_class
	AsyncronusReply
      end
      
      def result=(ev)
	@result = ev
	if @callback
	  Thread.start do
	    if ev.exp
	      exp = create_exception
	      @callback.call(nil, exp)
	    else
	      @callback.call(ev.result, nil)
	    end
	  end
	end
      end
    end

    class MQRequest<IteratorRequest
      def MQRequest.request(session, receiver, method, args, callback)
	req = new(session, receiver, method, args, callback)
	req.init_req
	req
      end

      def MQRequest.receipt(session, seq, receiver, method, args, callback)
	rec = new(session, receiver, method, args, callback)
	rec.set_seq(seq)
	rec
      end


      def initialize(session, receiver, method, args, callback = nil)
	super(session, receiver, method, args, callback)
	@callback = callback
      end
      attr_reader :callback

      def reply_class
	MQReply
      end
    end
    
    class SessionRequest < Request
      def SessionRequest.request(session, method, args=[])
	req = new(session, session, method, args)
	req.init_req
	req
      end

      def SessionRequest.receipt(session, seq, dummy, method, args=[])
	rec = new(session, session, method, args)
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
	sel = [self.class, @seq, @receiver.peer_id, @method]
	sel.push args
	sel
      end

      def inspect
	#	sprintf "#<#{self.class}, session=#{@session}, seq=#{@seq}, method=#{@method.id2name}, args=#{@args.collect{|e| e.to_s}.join(', ')}>"
	sprintf "#<#{self.class}, session=#{@session}, seq=#{@seq}, method=#{@method.id2name}, args=...>"
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
#	    Reference.serialize(@session.deep_space, @receiver),
	    nil,
	    @method,
	    sel_result,
	    Reference.serialize(@session.deep_space, @exp)]
	else
	  [self.class, @seq, 
#	    Reference.serialize(@session.deep_space, @receiver),
	    nil,
	    @method,
	    sel_result]
	end
      end

      def request?
	false
      end
      
      attr_reader :result
      attr_reader :exp
      attr_reader :method

      def inspect
	sprintf "#<#{self.class}, session=#{@session}, seq=#{@seq}, receiver=#{@receiver}, method=#{@method} result=#{@result} exp=#{@exp}}>"
      end
    end

    class IteratorReply < Reply; end

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
#	    Reference.serialize(@session.deep_space, @receiver),
	    nil,
	    @method,
	    sel_result,
	    Reference.serialize(@session.deep_space, @exp)]
	else
	  [self.class, @seq, 
#	    Reference.serialize(@session.deep_space, @receiver),
	    nil,
	    @method,
	    sel_result]
	end
      end
    end

    class IteratorCallBackReplyBreak<IteratorCallBackReply; end
    class IteratorReplyFinish < Reply; end

    class AsyncronusReply<Reply; end

    class MQReply<Reply;end

    class SessionReply < Reply
      def SessionReply.materialize_sub(session, type, klass, seq, receiver, method, ret, exp = nil)
	#	puts "SESSIONREPLY: #{type}, #{session}, #{ret.collect{|e| e.to_s}.join(',')}"	
	if exp
	  type.new(session, seq,
		   session,
		   method,
		   Reference.materialize(session.deep_space, *ret),
		   Reference.materialize(session.deep_space, *exp))
	else
	  type.new(session, seq,
		   session,
		   method,
		   Reference.materialize(session.deep_space, *ret))
	end
      end

      def inspect
	sprintf "#<#{self.class}, session=#{@session}, seq=#{@seq},  result=#{@result}}>"
      end
    end

    # session 初期化
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

    class ConnectResult<Event
      def self.materialize_sub(session, type, klass, result)
	new(result)
      end

      def initialize(result)
	@result = result
      end

      attr_reader :result

      def serialize
	[self.class, @result]
      end
    end
  end
end

