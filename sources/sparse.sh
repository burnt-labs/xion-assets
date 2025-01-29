#!/usr/bin/env bash

set -euo pipefail

SOURCES_DIR=$(cd $(dirname $0) && pwd)

cd $SOURCES_DIR
for dir in $(ls -d */); do
    dir=$(basename $dir)
    echo "found dir: $dir"
    cd $dir
    echo "setting sparse checkout on: $dir"
    git config core.sparse-checkout true
    find * -type f -name '*xion*' | sed 's/^.\.//' | tee ../../.git/modules/sources/$dir/info/sparse-checkout
    git read-tree -mu HEAD
    cd ..
done
