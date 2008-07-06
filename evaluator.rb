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

    def evaluate_iterator_request(session, event)
      begin 
	fin = event.receiver.send(event.method, *event.args){|*ret|
	  begin
	    session.accept Event::IteratorReply.reply(session, event, ret)
	    case evn = session.iterator_event_pop(event.seq)
	    when Event::IteratorNextRequest
	    when Event::IteratorExitRequest
	      return
	    end
	  rescue
	    session.accept Event::IteratorReply.reply(session, event, ret, $!)
	  end
	}
	session.accept Event::IteratorReplyFinish.reply(session, event, fin)
      rescue Exception
	session.accept Event::IteratorReplyFinish.reply(session, event, fin, $!)
      ensure
	session.iterator_exit(event.seq)
      end
    end
  end
end
