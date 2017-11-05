#!/bin/sh

set -eu
DOCKER_DIR="$(dirname "$(readlink -f "$0")")"

if [ -z "${GOPATH:-}" ]; then
	GOPATH=$PWD
	mkdir -p "$PWD/bin" "$PWD/src" "$PWD/pkg"
fi

set -x
DOCKER_ID="$(docker build -q --rm "$DOCKER_DIR")"
set --  --rm \
	-v "$GOPATH:/go" \
	-ti "$DOCKER_ID" "$@"

exec docker run "$@"
