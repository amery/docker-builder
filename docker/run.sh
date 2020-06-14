#!/bin/sh

set -eu

# Variables:
#   DOCKER_DIR         ${DOCKER_DIR}/Dockerfile
#   DOCKER_RUN_ENV     variables to passthrough if defined
#   DOCKER_RUN_VOLUMES variables that specify extra directories to mount
#
# Hooks:
#   ${DOCKER_DIR}/run-hook.in

die() {
	echo "$*" >&2
	exit 1
}

if [ "x${1:-}" = "x-r" ]; then
	USER_IS_SUDO=true
	shift
else
	USER_IS_SUDO=
fi

# select image
#
if [ -z "${DOCKER_DIR:-}" ]; then
	RUN_SH="$0"
	DOCKER_DIR="$(dirname "$RUN_SH")"

	while [ ! -s "$DOCKER_DIR/Dockerfile" ]; do
		if [ -L "$RUN_SH" ]; then
			# follow symlink
			RUN_SH="$DOCKER_DIR/$(readlink "$RUN_SH")"
			DOCKER_DIR="${RUN_SH%/*}"
		else
			die "$0: failed to detect Dockerfile"
		fi
	done
elif [ ! -s "$DOCKER_DIR/Dockerfile" ]; then
	die "$DOCKER_DIR: invalid docker directory"
fi

# build image
#
docker build --rm "$DOCKER_DIR"
DOCKER_ID="$(docker build --rm -q "$DOCKER_DIR")"

# find root of the "workspace"
#
find_repo_workspace_root() {
	if [ -d "$1/.repo" ]; then
		echo "$1"
	elif [ "${1:-/}" != / ]; then
		find_repo_workspace_root "${1%/*}"
	fi
}
WS="$(find_repo_workspace_root "$PWD")"

if [ -z "$WS" ]; then
	find_git_root() {
		if [ -s "$1/.git/HEAD" -o -s "$1/.git" ]; then
			echo "$1"
		fi

		if [ "${1:-/}" != / ]; then
			find_git_root "${1%/*}"
		fi
	}
	WS="$(find_git_root "$PWD" | tail -n1)"
fi

[ -d "$WS" ] || WS="$PWD"

# preserve user identity
#
USER_NAME="$(id -urn)"
USER_UID="$(id -ur)"
USER_GID="$(id -gr)"

set -- \
	${USER_IS_SUDO:+-e USER_IS_SUDO=true} \
	-e USER_HOME="$HOME" \
	-e USER_NAME="$USER_NAME" \
	-e USER_UID="$USER_UID" \
	-e USER_GID="$USER_GID" \
	-e CURDIR="$PWD" \
	-e WS="$WS" \
	"$DOCKER_ID" "$@"

# persistent volumes
#
if [ -z "${DOCKER_RUN_CACHEDIR:-}" ]; then
	DOCKER_RUN_CACHEDIR="$WS/.docker-run-cache"
fi

home_dir="$DOCKER_RUN_CACHEDIR/home/$USER_NAME"
parent_dir="$(dirname "$PWD")"

volumes() {
	local v= x=
	for v; do
		# name to value
		eval "echo \"\${$v:-}\""
	done | sort -uV | while read x; do
		# skip empty lines
		[ -n "$x" -a '/' != "$x" ] || continue

		# create missing directories
		[ -d "$x/" ] || mkdir -p "$x"

		# prevent root-owned directories at $home_dir
		case "$x" in
		"$HOME"/*|"$HOME")
			x0="${x#$HOME}"
			mkdir -p "$home_dir$x0"
			;;
		esac

		# render -v pairs
		case "$x" in
		"$HOME")
			echo "-v \"$home_dir:$x\""
			;;
		*)
			echo "-v \"$(readlink -f "$x"):$x\""
			;;
		esac
	done | tr '\n' ' '
}

gen_env() {
	local x= v=
	for x; do
		eval "v=\"\${$x:-}\""
		if [ -n "$v" ]; then
			echo "-e \"$x=$v\""
		fi
	done | tr '\n' ' '
}

# hook to extend run.sh before mounting volumes or exporting variables
#
if [ -s "$DOCKER_DIR/run-hook.in" ]; then
	. "$DOCKER_DIR/run-hook.in"
fi

# add more options
#
# volumes -> -v
# gen_env -> -e
#
eval "set -- \
	$(volumes ${DOCKER_RUN_VOLUMES:-} parent_dir HOME PWD WS) \
	$(gen_env ${DOCKER_RUN_ENV:-}) \
	\"\$@\""

# PTRACE
set -- \
	--cap-add SYS_PTRACE \
	--security-opt apparmor:unconfined \
	--security-opt seccomp:unconfined \
	"$@"

# isatty()
if [ -t 0 ]; then
	set -- -ti "$@"
fi

# and finally run within the container
set -x
exec docker run --rm "$@"
