#
# Makefile for perfSONAR Testbed
#

default: up



#
# Cron Job for Nightly Rebuilds
#

DIR := $(shell pwd)
KEY := $(shell pwd | tr / _)

REBUILD_LOG=rebuild.log
cron-add:
	@echo Adding crontab 
	@crontab -l 2>/dev/null \
	| sed -e '/KEY=$(KEY)/d' \
	| ( cat && echo '0 20 * * * make "KEY=$(KEY)" -C $(DIR) nightly-rebuild > $(DIR)/$(REBUILD_LOG) 2>&1') \
	| crontab
TO_CLEAN += $(REBUILD_LOG)


cron-remove:
	@echo Removing crontab 
	@crontab -l 2>/dev/null \
	| sed -e '/KEY=$(KEY)/d' \
	| crontab



#
# Nightly Rebuild
#

NIGHTLY_REBUILD_LIST := nightly-rebuild-list
$(NIGHTLY_REBUILD_LIST): config.yaml find-rebuilds Makefile
	rm -f "$@"
	./find-rebuilds < $< > "$@"
TO_CLEAN += $(NIGHTLY_REBUILD_LIST)


nightly-rebuild: $(NIGHTLY_REBUILD_LIST)
	@for HOST in $$(cat $(NIGHTLY_REBUILD_LIST)) ; \
	do \
	    vagrant destroy -f "$$HOST" ; \
	    vagrant up "$$HOST" ; \
	done



#
# Vagrant
#

up: cron-add
	vagrant up | tee up.log
TO_CLEAN += up.log

halt: cron-remove
	vagrant halt | tee halt.log
TO_CLEAN += halt.log

destroy: cron-remove
	vagrant destroy -f



#
# Everything Else
#

clean: destroy
	rm -rf $(TO_CLEAN) *~
