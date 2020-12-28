#!/bin/sh
[ $# -gt 0 ] || exit

sed -e 's|\(@@[^@]\+@@\)|\n\1\n|g' -- "$@" | sed -n -e 's|^@@\([^@]\+\)@@$|\1|p' | sort -uV
