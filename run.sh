#!/bin/sh

set -eu
DOCKER_DIR="$(dirname "$(readlink -f "$0")")"

if [ -z "${GOPATH:-}" ]; then
	GOPATH=$PWD
	mkdir -p "$PWD/bin" "$PWD/src" "$PWD/pkg"
fi

docker build --rm "$DOCKER_DIR"
DOCKER_ID="$(docker build -q --rm "$DOCKER_DIR")"
set -- \
	-e USER_NAME="$(id -urn)" \
	-e USER_UID="$(id -ur)" \
	-e USER_GID="$(id -gr)" \
	${DOCKER_EXPOSE:+-p $DOCKER_EXPOSE:$DOCKER_EXPOSE} \
	-v "$GOPATH:/go" \
	"$DOCKER_ID" "$@"

if [ -t 0 ]; then
	set -- -ti "$@"
else
	set -- -i "$@"
fi

exec docker run --rm "$@"
