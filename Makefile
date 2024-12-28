.PHONY: vv base help build static dev run-dev again active start prep bash q demo watch moar ubuntu-dev rebast

RELEASE = jammy

export DQLITED_SHELL = paulstuart/dqlited-alpine-dev:latest
export DQLITED_IMAGE = paulstuart/dqlited-scratch:latest

IMG = paulstuart/dqlited:$(RELEASE)
GIT = /root/go/src/github.com
MNT = $(GIT)/paulstuart/dqlited
CMN	= /Users/paul.stuart/CODE/DQLITE
DQL	= $(CMN)/src/paulstuart/dqlite
FRK	= $(CMN)/debian/Xenial/FORK

COMPOSER_CLUSTER = "dqlbox1:9181,dqlbox2:9182,dqlbox3:9183"
COMPOSE = docker compose --project-directory . -p dqlited -f docker/docker-compose.yml

help:	## this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

rebast:
	$(COMPOSE) restart bastion

.PHONY: hammer

hammer:
	./scripts/exec.sh dqlited hammer

.PHONY: kill local redo depends rerun triad tz usr1 usr2 stats logs

redo:	build kill clean start

triad::	kill watch start

rerun:	kill clean watch start prep moar

local:
	@./local

demo: kill watch start prep ## demonstrate the cluster bring up and fault tolerance
	
# docker build targets
.PHONY: ubuntu debug docker dqlited-dev dqlited-prod dq dtest hey dangling dangle timeout tcp dqlited-static

timeout:
	echo 1 > /proc/sys/net/ipv4/tcp_fin_timeout

tcp:
	cat /proc/sys/net/ipv4/tcp_fin_timeout

.PHONY: down up restart ps top bastion clu bounce status comptest d1 d2 net log

comptest:
	@$(COMPOSE) up -d bastion

d1:
	@$(COMPOSE) exec dqlbox1 bash
	@#$(COMPOSE) up -d dqlbox1

d2:
	@$(COMPOSE) exec dqlbox2 bash

ID =? 1

bounce:
	@$(COMPOSE) restart dqlbox$(ID)

clu:
	@$(COMPOSE) exec bastion ./dqlited cluster -c $$DQLITE_CLUSTER

bastion:
	@$(COMPOSE) exec bastion bash

kill:
	@pkill dqlited || :

.phony: goversion fmt clean

clean:
	rm -rf /tmp/dqlited*

watch:
	@scripts/active.sh -w

moar:
	@DQLITED_ROLE=voter scripts/start.sh 4 5

active:
	@scripts/active.sh

bash:
	@scripts/exec.sh bash

start:
	@scripts/start.sh

status: ## show cluster status
	@scripts/exec.sh dqlited status

prep:
	@scripts/prep.sh

# docker targets
.PHONY: forked try mine run dqx run-ubuntu

DEVIMG = paulstuart/dqlite-dev:$(RELEASE)

run-ubuntu:
	docker run \
		-it --rm \
		--workdir $(MNT) \
		paulstuart/ubuntu-base:$(RELEASE) bash

run:
	docker run \
		-it --rm \
		-p 9001:9001 \
		--workdir $(MNT) \
                --mount type=bind,src="$(DQL)",dst=/opt/build/dqlite 						\
                --mount type=bind,src="$(FRK)/go-dqlite",dst=/root/go/src/github.com/canonical/go-dqlite 	\
                --mount type=bind,src="$(PWD)",dst=$(MNT) \
		$(IMG) bash


DOCKER_CLUSTER = "127.0.0.1:9181,127.0.0.1:9182,127.0.0.1:9183,127.0.0.1:9184,127.0.0.1:9185"
LOCAL_CLUSTER = "@/tmp/dqlited.1.sock,@/tmp/dqlited.2.sock,@/tmp/dqlited.3.sock"

# run docker with my forks mounted over originals
mine:
	@docker run \
		-it --rm \
		--network=dqlite-network				\
		--env DQLITED_CLUSTER="$(DOCKER_CLUSTER)"		\
		--workdir $(MNT) 					\
                --mount type=bind,src="$(DQL)",dst="/opt/build/dqlite" 	\
                --mount type=bind,src="$(PWD)",dst=$(MNT) 		\
                --mount type=bind,src="$(PWD)/../FORK/go-dqlite",dst=$(MASTER) 	\
		${DEVIMG} bash

.PHONY: udev bionic

# temp target for testing canonical/raft on ubuntu bionic
bionic:
	docker run \
		-it --rm \
		--privileged								\
		--workdir $(MNT) 							\
                --mount type=bind,src="$(PWD)",dst=$(MNT) 				\
		ubuntu:bionic bash

# temp target for testing image
udev:
	docker run \
		-it --rm \
		-p 4001:4001 \
		-e DQLITED_CLUSTER=$(DOCKER_CLUSTER)					\
		--privileged								\
		--workdir $(MNT) 							\
                --mount type=bind,src="$(DQL)",dst=/opt/build/dqlite 			\
                --mount type=bind,src="$(PWD)/../FORK/go-dqlite",dst=$(MASTER) 		\
                --mount type=bind,src="$(PWD)",dst=$(MNT) 				\
		paulstuart/ubuntu-dev:$(RELEASE) bash

# dev image with local forks mounted in place of originals
# expose port 6060 to share local go docs
dq:
	docker run \
		-it --rm \
		-p 9001:9001 \
		-p 6060:6060 \
		-e DQLITED_CLUSTER=$(COMPOSER_CLUSTER)					\
		-e PATH=$(MNT):$$PATH							\
		--privileged								\
		--workdir $(MNT) 							\
                --mount type=bind,src="$(DQL)",dst=/opt/build/dqlite 			\
                --mount type=bind,src="$(PWD)/../FORK/go-dqlite",dst=$(MASTER) 		\
                --mount type=bind,src="$(PWD)",dst=$(MNT) 				\
		--network dqlite-network						\
		paulstuart/dqlited-alpine-dev bash

# same as dq but no ports published
dqx:
	docker run \
		-it --rm \
		-e DQLITED_CLUSTER=$(COMPOSER_CLUSTER)					\
		-e PATH=$(MNT):$$PATH							\
		--privileged								\
		--workdir $(MNT) 							\
                --mount type=bind,src="$(DQL)",dst=/opt/build/dqlite 			\
                --mount type=bind,src="$(PWD)/../FORK/go-dqlite",dst=$(MASTER) 		\
                --mount type=bind,src="$(PWD)",dst=$(MNT) 				\
		--network dqlite-network						\
		paulstuart/dqlited-alpine-dev bash

.PHONY: comp prodtest orig

# dev image with no forks
orig:
	docker run \
		-it --rm \
		-p 4001:4001 \
		-p 6060:6060 \
		-e DQLITED_CLUSTER=$(DOCKER_CLUSTER)					\
		--privileged								\
		--workdir $(MNT) 							\
                --mount type=bind,src="$(PWD)",dst=$(MNT) 				\
		paulstuart/dqlite-dev:$(RELEASE) bash

# testing image used for composer
comp:
	docker run \
		-it --rm \
		-e DQLITED_CLUSTER=$(DOCKER_CLUSTER)					\
		--privileged								\
		--workdir $(MNT) 							\
		paulstuart/dqlite-dev:$(RELEASE) bash

# testing image used for composer
prodtest:
	docker run \
		-it --rm \
		-e DQLITED_CLUSTER=$(DOCKER_CLUSTER)					\
		--privileged								\
		--workdir $(MNT) 							\
		paulstuart/dqlite-prod:$(RELEASE) bash

dqxXX:
	docker run \
		-it --rm \
		-p 4001:4001 \
		-e DQLITED_CLUSTER=$(LOCAL_CLUSTER)					\
		--privileged								\
		--workdir $(MNT) 							\
                --mount type=bind,src="$(DQL)",dst=/opt/build/dqlite 			\
                --mount type=bind,src="$(PWD)/../FORK/go-dqlite",dst=$(MASTER) 		\
                --mount type=bind,src="$(PWD)",dst=$(MNT) 				\
		paulstuart/dqlite-dev:$(RELEASE) bash

runX:
	docker run \
		-it --rm \
		-p 4001:4001 \
		--workdir $(MNT) \
                --mount type=bind,src="$(DQL)",dst=/opt/build/dqlite 						\
                --mount type=bind,src="$(CMN)/go-dqlite",dst=/root/go/src/github.com/canonical/go-dqlite 	\
                --mount type=bind,src="$(PWD)/../FORK/go-dqlite",dst=$(MASTER) 	\
                --mount type=bind,src="$(PWD)",dst=$(MNT) \
		$(IMG) bash

run-dev:
	docker run \
		-it --rm \
		-p 4001:4001 \
		--workdir $(MNT) \
                --mount type=bind,src="$$PWD",dst=$(MNT) \
		paulstuart/dqlite-dev:$(RELEASE) bash

#
# for testing chaings to a forked copy of github.com/canonical/go-dqlite
#
MASTER = /root/go/src/github.com/canonical/go-dqlite

forked:
	@docker run \
		-it --rm \
		-p 4001:4001 \
		--workdir $(MASTER) 					\
                --mount type=bind,src="$(DQL)",dst="/opt/build/dqlite" 	\
                --mount type=bind,src="$(PWD)",dst=$(MNT) 		\
                --mount type=bind,src="$(PWD)/../FORK/go-dqlite",dst=$(MASTER) 	\
		paulstuart/dqlited:$(RELEASE) bash

again:
	@docker exec \
		-it \
		--workdir $(MASTER) 					\
		thirsty_wing bash
edit:
	docker run \
		-it --rm \
		--workdir $(MNT) \
                --mount type=bind,src="$(CMN)/go-dqlite",dst=/root/go/src/github.com/canonical/go-dqlite 	\
                --mount type=bind,src="$(PWD)",dst=$(MNT) \
		$(DEVIMG) bash