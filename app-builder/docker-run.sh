#!/bin/sh

set -eu

ARG0="$(readlink -f "$0")"
SCRIPTS_DIR="$(dirname "$ARG0")"
WS=$(dirname "$0")

case "${1:-}" in
	--root|--version|"")
		# skip run.sh
		;;
	*)
		set -- "$SCRIPTS_DIR/run.sh" "$@"
		;;
esac

if [ -x "$(which docker)" ]; then
	exec "$WS/docker-run.sh" "$@"
else
	exec "$@"
fi
