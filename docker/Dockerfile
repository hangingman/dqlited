
######################################################################################
#
# A miminal but useful setup of ubuntu for building, testing, and hosting
# it builds upon the reference dqlite image to allow to stare and compare
#

# bionic and others seem to have issues on docker mac (stable)
ARG RELEASE=jammy
ARG GO_VERSION=go1.22.0
ARG GITHUB_USER=hangingman

FROM ubuntu:${RELEASE} AS base-os
ARG RELEASE
ARG GO_VERSION
ARG GITHUB_USER

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=US/Pacific

RUN echo "using release: ${RELEASE}"

# Do not exclude man pages & other documentation (as of Bionic)
RUN rm -f /etc/dpkg/dpkg.cfg.d/excludes

RUN apt-get update

# make install happy
RUN apt-get install -y apt-utils

# basics for repo mgmt
RUN apt-get install -y 			\
	ca-certificates				\
	software-properties-common 	\
	apt-transport-https &&		\
	apt-get update

# tools that are nice to have whilst logged in
RUN apt-get install -y 	\
	curl		\
	dnsutils 	\
	gdb 		\
	git 		\
	iputils-ping	\
	jq 			\
	lsof 		\
	man 		\
	man-db		\
	manpages 	\
	mercurial 	\
	net-tools	\
	netcat	 	\
	nmap	 	\
	socat	 	\
	sudo	 	\
	strace		\
	telnet		\
	wamerican	\
	vim

RUN ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime

######################################################################################
#
# create an image for building dqlite from scratch
# it builds upon the reference dqlite image to allow to stare and compare
#
FROM base-os AS dev-env

RUN apt-get update

RUN apt-get install -y 	\
	autoconf 	\
	automake 	\
	gcc		\
	git 		\
	libaio-dev	\
	libncurses-dev	\
	libreadline-dev	\
	libtool 	\
	make 		\
	pkg-config 	\
	tcl-dev \
	liblz4-dev \
	libsqlite3-dev

# set up Go
RUN cd /usr/local && \
	curl -skL https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz | tar -xzf -

RUN mkdir -p /root/go/bin /root/go/mod /root/go/pkg /root/go/src
ENV PATH=/usr/local/go/bin:/root/go/bin:$PATH
RUN echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc

# the build area for C libraries
RUN mkdir /opt/build
WORKDIR /opt/build

# make sure rebuilt libraries supercede installed versions
RUN printf "/usr/local/lib\ninclude /etc/ld.so.conf.d/*.conf\n" > /etc/ld.so.conf && ldconfig

# host mode of git uses ssh, but we don't want that inside docker container
RUN git config --global url."https://github.com/".insteadOf "git@github.com:"
RUN go install github.com/go-task/task/v3/cmd/task@latest
RUN go install github.com/go-delve/delve/cmd/dlv@latest

# make gdb happier with Go
RUN echo "add-auto-load-safe-path /usr/local/go/src/runtime/runtime-gdb.py" >> /root/.gdbinit

# move this up once its working correctly
RUN git clone https://github.com/fatih/vim-go.git ~/.vim/pack/plugins/start/vim-go

# TODO: move this up to base-os
RUN echo "alias vi='vim'" >> ~/.bash_aliases

# lets use local time for developing
RUN ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime

######################################################################################
#
# create an image for building dqlite from scratch
# it builds upon the reference dqlite image to allow to stare and compare
#
FROM dev-env AS dqlited-dev

RUN apt-get update

# gather all the sources required to build dqlite
# note that the repos will need to be updated after this image is built
RUN mkdir -p /opt/build/scripts
RUN mkdir -p /opt/build/src
COPY scripts/build_dqlite.sh /opt/build/scripts/
COPY scripts/sources.sh /opt/build/scripts/
WORKDIR /opt/build/src
RUN /opt/build/scripts/sources.sh .
RUN /opt/build/scripts/build_dqlite.sh all


WORKDIR /root/go/src/github.com/${GITHUB_USER}/dqlited 
COPY . ./

RUN go get -u -v ... || :

RUN task static

#RUN go clean -i

RUN echo "export PATH=$PWD:\$PATH" >> ~/.bashrc

######################################################################################
#
# create a production image (but with having nice things for debugging)
#

# FROM base-os AS dqlited-prod
# whilst testing
FROM dqlited-dev AS dqlited-prod

#RUN scripts/sources.sh .

WORKDIR /root/go/src/github.com/${GITHUB_USER}/dqlited/

# TESTING
RUN  rm -rf *
COPY . ./
#COPY *.go /root/go/src/github.com/${GITHUB_USER}/dqlited/

COPY . ./

# TESTING
RUN task static

# revert to this after testing

#COPY  --from=dqlited-dev /root/go/src/github.com/${GITHUB_USER}/dqlited/dqlited /usr/local/bin/

#COPY  --from=dqlited-dev /usr/local/bin/sqlite3 /usr/local/bin/
