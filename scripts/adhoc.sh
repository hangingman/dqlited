#!/bin/bash
set -e

cd $(dirname $0)
./exec.sh ./dqlited adhoc "$*"
