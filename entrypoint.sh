#!/bin/sh

set -eu

[ -n "${USER_UID:-}" ] || USER_UID=1000
[ -n "${USER_GID:-}" ] || USER_GID="$USER_UID"
[ -n "${USER_NAME:-}" ] || USER_NAME="node"
[ -n "${USER_HOME:-}" ] || USER_HOME="/home/$USER_NAME"
[ -n "${CURDIR:-}" ] || CURDIR="$PWD"

addgroup -S -g "$USER_GID" "$USER_NAME"
adduser -S -s /bin/sh \
	-h "$USER_HOME" \
	-G "$USER_NAME" \
	-u "$USER_UID" "$USER_NAME"

USER_PROFILE="$USER_HOME/.profile"
cat <<EOT > "$USER_PROFILE"
cd "$CURDIR"
pwd
env
EOT

if [ $# -gt 0 ]; then
	cat <<-EOT >> "$USER_PROFILE"
	set -x
	exec $*
	EOT
fi

su - "$USER_NAME"
