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

require "reference"

module DIST
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

    class Request < Event
      SEQ = [0]
    
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
	  @results.pop
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

    class SessionRequest < Request
      def SessionRequest.request(session, method, *args)
	req = new(session, session, method, *args)
	req.init_req
	req
      end

      def SessionRequest.receipt(session, seq, dummy, method, *args)
#	p "ZXXS"
	rec = new(session, session, method, *args)
	rec.set_seq(seq)
#	p rec
	rec
      end

      def reply_class
	SessionReply
      end
    
      def inspect
	sprintf "#<#{self.class}, session=#{@session}, seq=#{@seq}, method=#{@method.id2name}, args=#{@args.collect{|e| e.to_s}.join(', ')}>"
      end
    end

    class Reply < Event
      def Reply.materialize_sub(session, type, klass, seq, receiver, ret)
	type.new(session, seq, 
		 session.root(receiver), 
		 Reference.materialize(session, *ret))
      end
    
      def initialize(session, seq, receiver, ret)
	super(session, receiver)
	@seq = seq
	@result = ret
      end
    
      def serialize
	[self.class, @seq, 
	  Reference.serialize(@session, @receiver),
	  Reference.serialize(@session, @result)]
      end
    
      def request?
	FALSE
      end
    
      def iterator?
	FALSE
      end
    
      attr :result

      def inspect
	sprintf "#<#{self.class}, session=#{@session}, seq=#{@seq}, receiver=#{@receiver}, result=#{@result}}>"
      end
    end

    class IteratorReply < Reply
      def iterator?
	TRUE
      end
    
      def finish?
	false
      end
    end

    class IteratorReplyFinish < IteratorReply
      def iterator?
	TRUE
      end
    
      def finish?
	true
      end
    end

    class SessionReply < Reply
      def SessionReply.materialize_sub(session, type, klass, seq, receiver, ret)
	puts "SESSIONREPLY: #{type}, #{session}, #{ret.collect{|e| e.to_s}.join(',')}"	
	type.new(session, seq, 
		 session, 
		 Reference.materialize(session, *ret))
      end

      def inspect
	sprintf "#<#{self.class}, session=#{@session}, seq=#{@seq},  result=#{@result.inspect}}>"
      end
    end
  end
end
