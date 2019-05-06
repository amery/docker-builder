#!/bin/sh

set -eu

# select image
DOCKER_DIR="$(dirname "$(readlink -f "$0")")"

# preserve user identity
USER_NAME=$(id -urn)
USER_UID=$(id -ur)
USER_GID=$(id -gr)

# build image
docker build --rm "$DOCKER_DIR"
DOCKER_ID="$(docker build --rm -q "$DOCKER_DIR")"

# find root of the workspace
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
		elif [ "${1:-/}" != / ]; then
			find_git_root "${1%/*}"
		fi
	}
	WS="$(find_git_root "$PWD" | tail -n1)"
fi

[ -d "$WS" ] || WS="$PWD"

set -- \
	-e USER_NAME="$USER_NAME" \
	-e USER_UID="$USER_UID" \
	-e USER_GID="$USER_GID" \
	-e USER_HOME="$HOME" \
	-e WS="$WS" \
	-w "$PWD" \
	"$DOCKER_ID" "$@"

# persistent volumes
home_dir="$PWD/.docker-run-cache/home/$USER_NAME"
parent_dir="$(dirname "$PWD")"

volumes() {
	local x=
	sort -uV | while read x; do
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
			echo "-v $home_dir:$x"
			;;
		*)
			echo "-v $(readlink -f "$x"):$x"
			;;
		esac
	done
}

set -- $(volumes <<EOT
$parent_dir
$HOME
$PWD
$WS
EOT
) "$@"

if [ -t 0 ]; then
	set -- -ti "$@"
else
	set -- -i "$@"
fi

set -x
exec docker run --rm "$@"
