#
#   evaluator.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#


require "deep-connect/event"
require "deep-connect/exceptions"

module DeepConnect
  class Evaluator
    def initialize(org)
      @organizer = org
    end

    def evaluate_request(session, event)
      begin
	if @organizer.shallow_connect?
#p mspec = Organizer::method_spec(event.receiver, event.method)
	  if !(mspec = Organizer::method_spec(event.receiver, event.method)) or
	      !mspec.interface?
	    DC.Raise NoInterfaceMethod, event.receiver.class, event.method
	  end
	end
	ret = event.receiver.send(event.method, *event.args)
	unless event.kind_of?(Event::NoReply)
	  session.accept event.reply(ret)
	end
      rescue Exception
	unless event.kind_of?(Event::NoReply)
	  session.accept event.reply(ret, $!)
	end
      end
    end

    class ItrBreak<Exception;end

    def evaluate_iterator_request(session, event)
      begin 
	fin = event.receiver.send(event.method, *event.args){|*args|
	  begin
#puts "evaluate_iterator_request: #{args.inspect}"
	    if args.size == 1 && args.first.kind_of?(Array)
	      args = args.first
	    end
#puts "evaluate_iterator_request 2: #{args.inspect}"
	    callback_req = Event::IteratorCallBackRequest.call_back_event(event, *args)
	    session.accept callback_req
	    callback_reply  = session.iterator_event_pop(event.seq)

	    case callback_reply
	    when Event::IteratorCallBackReplyBreak
	      raise ItrBreak
	    else
	      callback_reply.result
	    end
	  rescue
	    p $!, $@
	    DC.Raise InternalError, $!
	  end
	}
#	session.accept Event::IteratorCallBackRequestFinish.call_back_event(event)
	session.accept event.reply(fin)
      rescue InternalError
	raise
      rescue ItrBreak
	# do nothing
      rescue Exception
	session.accept event.reply(fin, $!)
      ensure
#	session.iterator_exit(event.seq)
      end
    end
  end
end
