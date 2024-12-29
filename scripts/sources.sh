#!/bin/bash
set -e

# gather all the sources required to build dqlite (the library)
# note that the repos will need to be updated after this image is built
repos=(
    "https://github.com/canonical/dqlite.git"
    "https://github.com/sqlite/sqlite.git --depth 20"
    "https://github.com/libuv/libuv.git"
    "https://github.com/canonical/raft.git"
)

# Clone repositories in parallel and capture errors
for repo in "${repos[@]}"; do
    (
        set -x  # Enable tracing inside the subshell
        git clone $repo
    ) &
done

wait

