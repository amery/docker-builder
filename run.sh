#!/bin/sh

set -eu

[ -n "${DOCKER_ID:-}" ] || DOCKER_ID=amery/node-webpack

USER_NAME=$(id -urn)
USER_UID=$(id -ur)
USER_GID=$(id -gr)

set -- \
	-e USER_NAME="$USER_NAME" \
	-e USER_UID="$USER_UID" \
	-e USER_GID="$USER_GID" \
	-e USER_HOME="$HOME" \
	-w "$PWD" \
	"$DOCKER_ID" "$@"

# $HOME
home_dir="$PWD/.docker-$USER_NAME-home"
[ -d "$home_dir" ] || mkdir "$home_dir"

# $PWD
if expr "$PWD" : "$HOME/" > /dev/null; then
	# be sure the mount point isn't _accidentally_ created by root
	mkdir -p "$home_dir/${PWD#$HOME/}"
fi

if [ "$PWD" != "$HOME" ]; then
	set -- -v "$PWD:$PWD" "$@"
fi
set -- -v "$home_dir:$HOME" "$@"

if [ -t 0 ]; then
	set -- -ti "$@"
else
	set -- -i "$@"
fi

exec docker run --rm "$@"
