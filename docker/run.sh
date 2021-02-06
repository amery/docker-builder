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
	-x)	set -x ;;
	--)	shift; break ;;
	*)	break ;;
	esac
	shift
done

# pass-through environment
#
for x in $DOCKER_ENV_LABELS USER_IS_SUDO; do
	DOCKER_RUN_ENV="${DOCKER_RUN_ENV:+$DOCKER_RUN_ENV }$x"
done

# detect run mode
#
DOCKER_RUN_MODE=
for x in $DOCKER_ENV_LABELS; do

	case "$x" in
	GOPATH)
		x=golang ;;
	*)
		continue ;;
	esac

	if ! echo "$DOCKER_RUN_MODE" | grep -q "^$x\$"; then
		DOCKER_RUN_MODE="${DOCKER_RUN_MODE:+$DOCKER_RUN_MODE
}$x"
	fi
done

# find root of the "workspace"
#
if [ ! -d "${DOCKER_RUN_WS:-}" ]; then
	CHECKER=

	for x in $DOCKER_RUN_MODE; do
		case "$x" in
		golang)
			f="test -d %/pkg"
			CHECKER="${CHECKER:+$CHECKER && }$f"
			;;
		esac
	done

	if [ -n "$CHECKER" ]; then
		eval "check_ws() { $(echo "$CHECKER" | sed -e 's|%|"$1"|g'); }"
		CHECKER=check_ws
	fi

	DOCKER_RUN_WS=$(builder_find_workspace $CHECKER)
fi

# initialise workspace based on run mode
for x in $DOCKER_RUN_MODE; do
	case "$x" in
	golang)
		[ -d "${GOPATH:-}" ] || GOPATH="$DOCKER_RUN_WS"
		mkdir -p "$GOPATH/bin" "$GOPATH/src" "$GOPATH/pkg"

		DOCKER_RUN_VOLUMES="${DOCKER_RUN_VOLUMES:+$DOCKER_RUN_VOLUMES } GOPATH"
		;;
	esac
done

# run
#
[ $# -gt 0 ] || set -- ${SHELL:-/bin/sh}

builder_run_exec "$DOCKER_RUN_WS" ${USER_IS_SUDO:+--cap-add=SYS_ADMIN} "$DOCKER_ID" "$@"
