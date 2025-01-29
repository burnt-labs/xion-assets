#!/usr/bin/env bash

set -x

for dir in $(find . -type d); do
    cd $dir
    git config sparse-checkout true
    echo "**xion**" .git/modules/sources/$dir/info/sparse-checkout
done
