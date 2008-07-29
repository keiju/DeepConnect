#require "profiler"

require "deep-connect/deep-connect"

require "deep-connect/future"


Thread.abort_on_exception=true
STDOUT.sync

#Tracer.on
dc = DeepConnect.start(65534)
deepspace = dc.open_deep_space("localhost", 65535)
#deepspace = dc.open_deep_space("gentoo", 65535)

ro = deepspace.import("foo")

#Profiler__.start_profile

#10000.times{ DeepConnect.future{ro.baz} }
10000.times{ ro.baz }

#Profiler__.print_profile(STDOUT)

exit

