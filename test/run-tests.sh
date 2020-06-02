#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TESTS_LUA="$DIR/tests.lua"
eval "nvim '+lua dofile(\"$TESTS_LUA\")'"
