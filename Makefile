PACKAGE_NAME = DeepConnect

SRCS =  Makefile \
	ChangeLog \
	TODO \
	$(wildcard lib/*.rb lib/deep-connect/*.rb test/*.rb)

tag-%:
	echo "Make tag $*"
	tools/git-tag $*

all:

pull-from-fairy:
	git pull /home/keiju/public/a.research/fairy/git/deep-connect

pull-from-emperor:
	git pull ssh://emperor/home/keiju/var/src/var.lib/ruby/deep-connect

pull-from-giant:
	git pull ssh://giant/home/keiju/var/src/var.lib/ruby/deep-connect

#
# github
push:
	git push

push-tags:
	git push --tags

#
# gem
gem:	
	@f=`gem build deep-connect.gemspec | sed -n "s/ *File: *//p"`; \
	echo gem build: $$f; \
	mv $$f Packages

push-gem: 
	@f=`tools/last-package Packages`; \
	gem push Packages/$$f

#
#
# doc
doc: doc/deep-connect.html

doc/deep-connect.html: doc/deep-connect.rd
	env RUBYLIB= RUBYOPT= rd2 -rrd/rd2html-lib --html-title="DeepConnect"  doc/deep-connect.rd > doc/deep-connect.html

# tar archives
TGZ_FILES = $(SRCS)


SNAPSHOT = Snapshot

VERSION = $(shell ruby -r lib/deep-connect/version.rb -e "puts DeepConnect::VERSION")

TAR_NAME = $(PACKAGE_NAME)-$(VERSION).tgz

tgz: $(SNAPSHOT)/$(TAR_NAME)

$(SNAPSHOT)/$(TAR_NAME): $(TGZ_FILES)
	@if [ ! -e $(SNAPSHOT) ]; then \
	    mkdir $(SNAPSHOT); \
	fi
	@echo "make $(TAR_NAME) in $(SNAPSHOT)"
	@tar zcf $(SNAPSHOT)/$(TAR_NAME) $(TGZ_FILES)
	@echo "copy $(TAR_NAME) to /tmp/Downloads"
	@cp -p $(SNAPSHOT)/$(TAR_NAME) /tmp/Downloads

