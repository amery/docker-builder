#!/bin/sh

set -eu

[ -n "${USER_UID:-}" ] || USER_UID=1000
[ -n "${USER_GID:-}" ] || USER_GID="$USER_UID"
[ -n "${USER_NAME:-}" ] || USER_NAME="gopher"
[ -n "${USER_HOME:-}" ] || USER_HOME="/home/$USER_NAME"

[ -n "${CURDIR:-}" ] || CURDIR="$PWD"
[ -n "${WS:-}" ] || WS="$CURDIR"

# create workspace-friendly user
addgroup -S -g "$USER_GID" "$USER_NAME"
adduser -s /bin/sh -S -h "$USER_HOME" \
	-G "$USER_NAME" -u "$USER_UID" \
	"$USER_NAME"

USER_PROFILE="$USER_HOME/.profile"

cat <<EOT > "$USER_PROFILE"
cd "$CURDIR"
export PATH="$WS/bin:/usr/local/go/bin:\$PATH"
export GOPATH="$WS"
export CGO_ENABLED=0
EOT

if [ $# -gt 0 ]; then
	cat <<-EOT >> "$USER_PROFILE"
	set -x
	exec $*
	EOT
fi

su - "$USER_NAME"
