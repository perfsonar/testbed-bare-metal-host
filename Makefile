#
# Makefile for perfSONAR Testbed
#


BIN := ./bin
CONFIG := ./config/config.yaml


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
$(NIGHTLY_REBUILD_LIST): config.yaml $(BIN)/find-rebuilds Makefile
	rm -f "$@"
	$(BIN)/find-rebuilds < $< > "$@"
TO_CLEAN += $(NIGHTLY_REBUILD_LIST)


nightly-rebuild: $(NIGHTLY_REBUILD_LIST)
	@for HOST in $$(cat $(NIGHTLY_REBUILD_LIST)) ; \
	do \
	    vagrant destroy -f "$$HOST" ; \
	    vagrant up "$$HOST" ; \
	    $(MAKE) "ansible-build-$$HOST" ; \
	done


#
# Vagrant
#

SSH_CONFIG := vagrant-ssh-config
$(SSH_CONFIG): FORCE
	vagrant ssh-config --no-tty > $@
TO_CLEAN += $(SSH_CONFIG)

up: cron-add
	vagrant up | tee up.log
	rm -f $(SSH_CONFIG)
	$(MAKE) $(SSH_CONFIG)
	$(MAKE) ansible
TO_CLEAN += up.log

# Vagrant sometimes leaves these around.
TO_CLEAN += *-*-*-*-*-*.*-VBoxHeadless-*.log

halt: cron-remove
	vagrant halt | tee halt.log
TO_CLEAN += halt.log

destroy: cron-remove
	vagrant destroy -f


#
# Ansible
#

MESH_REPO_NAME=perfsonar-dev-mesh

# TODO: Remove the cp command in this target.
$(MESH_REPO_NAME):
	git clone https://github.com/perfsonar/perfsonar-dev-mesh.git
	cp /home/mfeit/work/perfsonar-dev-mesh/site.yml ./perfsonar-dev-mesh/site.yml
	cd $@ && ansible-galaxy install -r requirements.yml
TO_CLEAN += $(MESH_REPO_NAME)

MESH_REPO_INVENTORY := $(MESH_REPO_NAME)/inventory/hosts
$(MESH_REPO_INVENTORY): $(MESH_REPO_NAME) $(CONFIG) FORCE
	$(BIN)/build-ansible-inventory < $(CONFIG) > $@

ansible: $(SSH_CONFIG) $(MESH_REPO_INVENTORY)
	git -C $(MESH_REPO_NAME) pull
	$(MAKE)  $(MESH_REPO_INVENTORY)
	ANSIBLE_SSH_ARGS="-F $(SSH_CONFIG)" \
		ansible-playbook \
		-i $(MESH_REPO_INVENTORY) \
		$(MESH_REPO_NAME)/site.yml \
		| tee ansible.log
TO_CLEAN += ansible.log

ansible-build-%: $(SSH_CONFIG)
	echo $@ | sed -e s'/^ansible-build-//g'
	false TODO: Build a single host by name

#
# Everything Else
#

clean: destroy
	rm -rf $(TO_CLEAN)
	find . -name "*~" | xargs rm -rf

FORCE:
