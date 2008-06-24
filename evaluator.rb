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
      ret = event.receiver.send(event.method, *event.args)
      session.accept event.reply_class.new(session, event.seq, event.receiver, ret)
    end

    def evaluate_iterator_request(session, event)
      fin = event.receiver.send(event.method, *event.args){
	|ret|
	session.accept Event::IteratorReply.new(session, event.seq, event.receiver, ret)
      }
      session.accept Event::IteratorReplyFinish.new(session, event.seq, event.receiver, fin)
    end
  end
end
