#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PACKMAN_LUA="$DIR/packman.lua"
TESTS_LUA="$DIR/test/tests.lua"
rm -rf "$DIR/test/pack"
eval "nvim --headless -u NONE '+lua dofile(\"$PACKMAN_LUA\")' '+lua dofile(\"$TESTS_LUA\")'"
