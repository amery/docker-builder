#!/bin/sh

set -eu

ARG0="$(readlink -f "$0")"
SCRIPTS_DIR="$(dirname "$ARG0")"
WS=$(dirname "$0")

set -- "$SCRIPTS_DIR/run.sh" "$@"
if [ -x "$(which docker)" ]; then
	exec "$WS/docker-run.sh" "$@"
else
	exec "$@"
fi
