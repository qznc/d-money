#!/bin/sh

# check directory layout
[ -d docs ] || exit 1
[ -d gh-pages ] || exit 1

# build documentation
export DDOCFILE=docs/custom.ddoc
dub run -b docs

# prepare for Github
cp docs/money.html gh-pages/index.html
