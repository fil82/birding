include .Makefile.d/command.mk

## Developer Tasks

run: Procfile
	$(POORMAN) start

docs: birding-dev
	@touch docs/todo.rst # Force rebuild of todolist.
	@PATH=$(VENDOR)/opt/python2.7/bin:$(PATH) $(MAKE) -C docs html

.PHONY: docs

flakes: pyflakes-command
	@find *.py src -name '*.py' | xargs pyflakes

## Run Recipes w/Automated Requirements

include .Makefile.d/procfile.mk
include .Makefile.d/vendor.mk
include .Makefile.d/wait.mk

sparse := $(VENDOR)/opt/python2.7/bin/sparse

Procfile: proc proc-zookeeper proc-kafka proc-streamparse proc-follow
.PHONY: Procfile

run: vendor-poorman
run: POORMAN := $(VENDOR)/usr/bin/poorman

# Add run dependencies to reduce race between processes.
run: vendor-kafka vendor-python2.7

# Ensure twitter credentials are in place.
run: run-twitter

run-twitter: birding-dev
	@echo Running twitter command to see if OAuth established ...
	@$(VENDOR)/opt/python2.7/bin/twitter

run-zookeeper: vendor-kafka
	$(DIR)/bin/zookeeper-server-start.sh $(DIR)/config/zookeeper.properties

run-kafka: vendor-kafka wait-tcp-2181
	$(wrapper) $(DIR)/bin/kafka-server-start.sh $(DIR)/config/server.properties

run-zookeeper run-kafka: DIR := $(VENDOR)/opt/kafka

run-streamparse: $(sparse) wait-tcp-9092
	@$(KAFKA_DIR)/bin/kafka-topics.sh --create --zookeeper localhost:2181 \
		--replication-factor 1 --partitions 1 --topic tweet ; true # KAFKA-2154
	@PATH=$(VENDOR)/opt/python2.7/bin:$(PATH) $(sparse) run

run-streamparse: KAFKA_DIR := $(VENDOR)/opt/kafka

run-follow: birding-dev wait-tcp-9092
	@$(wrapper) $(VENDOR)/opt/kafka/bin/kafka-console-consumer.sh \
		--zookeeper localhost:2181 --topic tweet | \
		$(VENDOR)/opt/python2.7/bin/python2.7 -m birding.follow

# Sending kafka SIGKILL is dramatic, but it does not exit if zookeeper is gone.
run-kafka run-follow: wrapper := .Makefile.d/bin/run-then-sigkill

$(sparse): .develop
birding-dev: .develop

.PHONY: birding-dev

develop: .develop
.develop: virtualenvs/birding.txt Makefile setup.py
	$(VENDOR)/opt/python2.7/bin/pip install sphinx sphinx-autobuild
	$(VENDOR)/opt/python2.7/bin/pip install -r $<
	$(VENDOR)/opt/python2.7/bin/python2.7 setup.py develop
	@touch $@

# Reinstall dependencies if Python goes missing or is reinstalled.
.develop: $(VENDOR)/opt/python2.7/bin/python2.7
$(VENDOR)/opt/python2.7/bin/python2.7: python2.7-command vendor-python2.7
