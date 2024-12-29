#!/usr/bin/env bash
set -e
set -o pipefail
set -o errtrace

trap 'echo "Error occurred at line $LINENO. Exiting..."; exit 1' ERR

say() { printf "\n$*\n\n"; }

libuv() {
say "building libuv"
cd libuv
git pull
git checkout v1.34.2 # latest version as of now
sh autogen.sh
./configure && make -j && make install
cd -
}

raft() {
say "building raft"
cd raft
git pull
autoreconf -i
./configure
make -j && make install
cd -
}

dqlite() {
say "building dqlite"
cd dqlite
git pull
autoreconf -i
#CFLAGS=-DDEBUG_VERBOSE=1 
./configure
make clean
make -j CFLAGS=-DDEBUG_VERBOSE=1 && make install
cd -
}

[[ -z $1 ]] && exit -1

cd /opt/build/src

# NOTE: dqlite does not depend on libco anymore
# NOTE: sqlite, we can just install the libsqlite3-dev package from Debian or Ubuntu
# https://github.com/canonical/dqlite/pull/267
while [[ -n $1 ]]; do
    case $1 in 
	libuv)  libuv ;;
	raft)   raft ;;
	dqlite) dqlite ;;
	all) libuv ; raft ; dqlite;;
    esac
    shift
done
