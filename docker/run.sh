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

# labels
#
docker_labels() {
	docker inspect --format "{{range \$Key, \$Value := .Config.Labels}}{{\$Key}}={{\$Value}}:{{end}}" "$1" | tr ':' '\n'
}

docker_env_labels() {
	docker_labels "$1" | grep '^docker-builder\.run-env\.' | cut -d= -f2- | tr ' ' '\n' | sort -u
}

docker_version_labels() {
	docker_labels "$1" | grep '^docker-builder\.version\.' | cut -d. -f3-
}

DOCKER_ENV_LABELS="$(docker_env_labels "$DOCKER_ID")"
DOCKER_VERSION_LABELS="$(docker_version_labels "$DOCKER_ID")"

# -r (sudo) mode
#
if [ "x${1:-}" = "x-r" ]; then
	USER_IS_SUDO=true
	shift
else
	USER_IS_SUDO=
fi

# pass-through environment
#
for x in $DOCKER_ENV_LABELS USER_IS_SUDO; do
	DOCKER_RUN_ENV="${DOCKER_RUN_ENV:+$DOCKER_RUN_ENV }$x"
done

# find root of the "workspace"
#
WS=$(builder_find_workspace)

# run
#
[ $# -gt 0 ] || set -- ${SHELL:-/bin/sh}

builder_run_exec "$WS" ${USER_IS_SUDO:+--cap-add=SYS_ADMIN} "$DOCKER_ID" "$@"
