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

    def evaluate(session, event)
      begin
	if event.iterator?
	  evaluate_iterator_request(session, event)
	else
	  evaluate_request(session, event)
	end
      rescue
      end
    end

    def evaluate_request(session, event)
      begin
	ret = event.receiver.send(event.method, *event.args)
	session.accept event.reply_class.new(session, event.seq, event.receiver, ret)
      rescue Exception
	session.accept event.reply_class.new(session, event.seq, event.receiver, ret, $!)
      end
    end

    def evaluate_iterator_request(session, event)
      begin 
	fin = event.receiver.send(event.method, *event.args){|ret|
	  begin
	    session.accept Event::IteratorReply.new(session, event.seq, event.receiver, ret)
	  rescue
	    session.accept Event::IteratorReply.new(session, event.seq, event.receiver, ret, $!)
	  end
	}
	session.accept Event::IteratorReplyFinish.new(session, event.seq, event.receiver, fin)
      rescue Exception
	session.accept Event::IteratorReplyFinish.new(session, event.seq, event.receiver, ret, $!)
      end
    end
  end
end
