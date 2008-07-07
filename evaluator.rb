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

module DeepConnect
  class Evaluator
    def initialize(org)
      @organizer = org
    end

#     def evaluate(session, event)
#       begin
# 	case event
# 	when IteratorNextRequest
# 	when IteratorRequest
# 	  evaluate_iterator_request(session, event)
# 	else
# 	  evaluate_request(session, event)
# 	end
#       rescue
#       end
#     end

    def evaluate_request(session, event)
      begin
	ret = event.receiver.send(event.method, *event.args)
	unless event.kind_of?(Event::NoReply)
	  session.accept event.reply(ret)
	end
      rescue Exception
	unless event.kind_of?(Event::NoReply)
	  session.accept event.reply( ret, $!)
	end
      end
    end

    class ItrBreak<Exception;end

    def evaluate_iterator_request(session, event)
      begin 
	fin = event.receiver.send(event.method, *event.args){|*args|
	  begin
	    session.accept Event::IteratorCallBackRequest.call_back_event(event, *args)
	    callback_reply  = session.iterator_event_pop(event.seq)

	    case callback_reply
	    when Event::IteratorCallBackReplyBreak
	      raise ItrBreak
	    else
	      callback_reply.result
	    end
	  end
	}
	session.accept Event::IteratorCallBackRequestFinish.call_back_event(event)
	session.accept event.reply(fin)
      rescue ItrBreak
	# do nothing
      rescue Exception
	session.accept event.reply(fin, $!)
      ensure
	session.iterator_exit(event.seq)
      end
    end
  end
end
