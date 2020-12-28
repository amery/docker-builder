#!/bin/sh

FIND_ARGS=
for x; do
	FIND_ARGS="${FIND_ARGS:+${FIND_ARGS} -o }-name $x.in"
done

if [ -n "$FIND_ARGS" ]; then
	find * $FIND_ARGS
fi | sed -e 's|\.in$||g'
