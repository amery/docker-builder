#!/bin/sh

set -eu

USER_HOME="/home/$USER_NAME"
USER_PROFILE="$USER_HOME/.profile"

# create workspace-friendly user
addgroup -S -g "$USER_GID" "$USER_NAME"
adduser -s /bin/sh -S -h "$USER_HOME" \
	-G "$USER_NAME" -u "$USER_UID" \
	"$USER_NAME"
cat <<EOT > "$USER_PROFILE"
cd "$GOPATH"
export PATH="/usr/local/go/bin:\$PATH"
export GOPATH=\$PWD
EOT

if [ $# -gt 0 ]; then
	echo "exec $*" >> "$USER_PROFILE"
fi

su - "$USER_NAME"
