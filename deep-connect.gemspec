
require "rubygems"

Gem::Specification.new do |s|
  s.name = "DeepConnect"
  s.authors = "Keiju Ishitsuka"
  s.email = "keiju@ishitsuka.com"
  s.platform = Gem::Platform::RUBY
  s.summary = "Distributed Object Framework for Ruby"
  s.rubyforge_project = s.name
  s.homepage = "http://github.com/keiju/DeepConnect"
  s.version = File.readlines("lib/deep-connect/version.rb").grep(/VERSION/).first.sub(/.*([0-9]+\.[0-9]+\.[0-9]+).*/, "\\1").chomp
  s.require_path = "lib"
#  s.test_file = ""
#  s.executable = ""
  s.files = ["lib/deep-connect.rb" ]
  s.files.concat Dir.glob("lib/deep-connect/*.rb")
  s.files.concat ["doc/deep-connect.rd", "doc/deep-connect.html"]
  s.description = <<EOF
Distributed Object Framework for Ruby.
EOF
end

# Editor settings
# - Emacs -
# local variables:
# mode: Ruby
# end:
