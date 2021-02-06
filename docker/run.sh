#!/bin/sh

set -eu

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

# special options
#
USER_IS_SUDO=
while [ $# -gt 0 ]; do
	case "$1" in
	-r)	USER_IS_SUDO=true ;;
	-l)	docker_labels "$DOCKER_ID" ;;
	*)	break ;;
	esac
	shift
done

# pass-through environment
#
for x in $DOCKER_ENV_LABELS USER_IS_SUDO; do
	DOCKER_RUN_ENV="${DOCKER_RUN_ENV:+$DOCKER_RUN_ENV }$x"
done

# find root of the "workspace"
#
if [ ! -d "$DOCKER_RUN_WS" ]; then
	DOCKER_RUN_WS=$(builder_find_workspace)
fi

# run
#
[ $# -gt 0 ] || set -- ${SHELL:-/bin/sh}

builder_run_exec "$DOCKER_RUN_WS" ${USER_IS_SUDO:+--cap-add=SYS_ADMIN} "$DOCKER_ID" "$@"
