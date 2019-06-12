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
export PATH="$GOPATH/bin:/usr/local/go/bin:\$PATH"
export GOPATH=\$PWD
export CGO_ENABLED=0
EOT

if [ $# -gt 0 ]; then
	cat <<-EOT >> "$USER_PROFILE"
	set -x
	exec $*
	EOT
fi

su - "$USER_NAME"
