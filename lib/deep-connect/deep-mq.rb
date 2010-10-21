# encoding: UTF-8
#
#   deep-mq.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

@RCS_ID='-$Id:  $-'


require "thread"

module DeepConnect
  module DeepMQ
    class SV
      def initialize(org)
        @organizer = org
        @event_q = Queue.new
        start
      end

      def enq(session, ev)
        begin
          @event_q.push [session, ev]
          session.accept ev.reply(nil)
        rescue SystemExit
          raise
        rescue Exception
	  session.accept event.reply(ret, $!)
        end
      end

      def start
        Thread.start do
          loop do
            evaluate_request(*@event_q.pop)
          end
        end
      end

      def evaluate_request(session, ev)
        receiver = ev.args.first
        method = ev.args[1]
        args = ev.args[2..-1]
        callback = ev.callback
        ev0 = Event::Request.request(session, receiver, method, args)
        @organizer.evaluator.evaluate_mq_request(session, ev0, callback)
      end
    end

    class CL
      def initialize(sv)
        @sv = sv
      end

      def push(ref, method, *arg, &callback)
        @sv.deep_space.session.mq_send_to(@sv, :push, [ref, method, *arg], callback)
      end
#      Organizer::def_method_spec(SV, "push(DEFAULT, DEFAULT, VAL)")
    end
  end
end
