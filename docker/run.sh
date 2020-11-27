#!/bin/sh

set -eu

# Variables:
#   DOCKER_DIR         ${DOCKER_DIR}/Dockerfile
#   DOCKER_ID          optional image id to use instead of building DOCKER_DIR
#   DOCKER_RUN_ENV     variables to passthrough if defined
#   DOCKER_RUN_VOLUMES variables that specify extra directories to mount
#   DOCKER_EXTRA_OPTS  extra options to pass as-is to `docker run`
#
# Hooks:
#   ${DOCKER_DIR}/run-hook.in

RUN_SH=$(readlink -f "$0")
. "$(dirname "$RUN_SH")/docker_builder_run.in"

# DOCKER_ID
if [ -z "${DOCKER_ID:-}" ]; then
	DOCKER_DIR="$(builder_find_docker_dir "$0" "${DOCKER_DIR:-}")"

	if [ -d "$DOCKER_DIR" ]; then
		docker build --rm "$DOCKER_DIR"
		DOCKER_ID="$(docker build -q --rm "$DOCKER_DIR")"
	fi
fi

# -r (sudo) mode
#
if [ "x${1:-}" = "x-r" ]; then
	USER_IS_SUDO=true
	shift
else
	USER_IS_SUDO=
fi

# find root of the "workspace"
#
WS=$(builder_find_workspace)
DOCKER_RUN_ENV="${DOCKER_RUN_ENV:+$DOCKER_RUN_ENV }USER_IS_SUDO"

# run
#
[ $# -gt 0 ] || set -- ${SHELL:-/bin/sh}

builder_run_exec "$WS" ${USER_IS_SUDO:+--cap-add=SYS_ADMIN} "$DOCKER_ID" "$@"
