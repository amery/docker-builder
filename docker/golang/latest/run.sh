#!/bin/sh

set -eu

# Variables:
#   DOCKER_DIR           ${DOCKER_DIR}/Dockerfile
#   DOCKER_ID            optional image id to use instead of building DOCKER_DIR
#   DOCKER_EXTRA_OPTS    extra options to pass as-is to `docker run`
#   DOCKER_RUN_CACHE_DIR
#   DOCKER_RUN_VOLUMES
#   DOCKER_RUN_ENV
#
#   GOPATH
#

RUN_SH=$(readlink -f "$0")
. "$(dirname "$RUN_SH")/../../docker_builder_run.in"

# DOCKER_ID
if [ -z "$(docker --version 2> /dev/null)" ]; then
	DOCKER_ID=
	DOCKER_DIR=
elif [ -z "${DOCKER_ID:-}" ]; then
	DOCKER_DIR="$(builder_find_docker_dir "$0" "${DOCKER_DIR:-}")"

	if [ -d "$DOCKER_DIR" ]; then
		docker build --rm "$DOCKER_DIR"
		DOCKER_ID="$(docker build -q --rm "$DOCKER_DIR")"
	fi
fi

# take GOPATH as the root of the workspace
#
if [ -z "${GOPATH:-}" ]; then
	# find GOPATH
	#
	test_gopath() {
		test -d "$1/pkg"
	}

	GOPATH=$(builder_find_workspace test_gopath)
fi

mkdir -p "$GOPATH/bin" "$GOPATH/src" "$GOPATH/pkg"

# run
#
[ $# -gt 0 ] || set -- ${SHELL:-/bin/sh}

if [ -n "$DOCKER_ID" ]; then
	builder_run_exec "$GOPATH" "$DOCKER_ID" "$@"
else
	export GOPATH
	exec "$@"
fi
