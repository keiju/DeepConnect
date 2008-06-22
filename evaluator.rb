#!/usr/local/bin/ruby
#
#   evaluator.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Nihon Rational Software Co.,Ltd)
#
# --
#
#   
#

require "event"

module DIST
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

    def evaluate_request_iterator(session, event)
      event.receiver.send(event.method, *event.args) do
	|ret|
	session.accept IteratorReply.new(event.seq, event.receiver, ret)
      end
      session.accept IteratorReplyFinish.new(event.seq, event.receiver)
    end
  end
end
