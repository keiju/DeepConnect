
require "deep-connect"
require "deep-fork"

dc = DeepConnect.start

dc.export("Foo", "FOO")

df = DeepConnect::DeepFork.fork(dc){|dc2, ds2|
  p 1
  p ds2.import("Foo")
  p 2
}

p "AAAAAAAAAA"

Process.wait(df.peer_pid)



