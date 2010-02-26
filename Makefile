PACKAGE_NAME = DeepConnect

SRCS =  Makefile \
	ChangeLog \
	TODO \
	$(wildcard *.rb test/*.rb)

tag-%:
	echo "Make tag $*"
	tools/git-tag $*

pull-from-fairy:
	git pull /home/keiju/public/a.research/fairy/git/deep-connect

#push:	
#	git push ssh://git-keiju@www.sota.me/var/www/html/fairy/fairy.git

#push-dev:
#	git push ssh://git-keiju@www.sota.me/var/www/html/fairy/fairy.git refs/heads/dev

#push-tags:	
#	git push --tags ssh://git-keiju@www.sota.me/var/www/html/fairy/fairy.git


# tar archives
TGZ_FILES = $(SRCS)


SNAPSHOT = Snapshot

VERSION = $(shell ruby -r version.rb -e "puts DeepConnect::VERSION")

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

