#!/bin/sh

RUN_SH="$(readlink -f "$0")"
export DOCKER_DIR="${RUN_SH%/*}"

export DOCKER_RUN_VOLUMES="DL_DIR"

exec "${DOCKER_DIR}/../../run.sh" "$@"
