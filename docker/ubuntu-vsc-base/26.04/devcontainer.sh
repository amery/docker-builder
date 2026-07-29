#!/bin/sh

set -eu

# the sourced runtime lib is absent at lint time
# shellcheck disable=SC1091
. /usr/local/lib/docker-builder/entrypoint.sh

REMOTE_USER="$1"
REMOTE_USER_HOME="$2"

#
# user's env
#

F=/etc/profile.d/Z99-devcontainer.sh
T="$F.$$"
gen_profile > "$T"
mv "$T" "$F"

if [ "$REMOTE_USER" != "vscode" ]; then
	# user's $HOME
	[ -n "$REMOTE_USER_HOME" ] || REMOTE_USER_HOME="/home/$REMOTE_USER"

	groupmod -n "$REMOTE_USER" vscode
	usermod -s /bin/bash -l "$REMOTE_USER" vscode
	if [ "$REMOTE_USER_HOME" != "/home/vscode" ]; then
		usermod -d "$REMOTE_USER_HOME" "$REMOTE_USER"
		# the target may live under a path absent from the base image
		# — e.g. Windows host-path parity homes at /C/Users/<name> —
		# so create the parent before renaming /home/vscode into it,
		# or mv aborts on the missing directory.
		mkdir -p "$(dirname "$REMOTE_USER_HOME")"
		mv /home/vscode "$REMOTE_USER_HOME"
	fi
fi

# The runtime directory the entrypoint makes at start; this image bypasses
# the entrypoint, so bake it at build time instead. It survives to runtime
# because Docker leaves /run as ordinary image filesystem rather than the
# tmpfs the FHS calls for — were that to change, the directory would be
# masked at start and a bind mount beneath it would go back to fabricating
# a root-owned parent. Resolved after the rename above, so it reads the
# final name either way; the UID it returns is untouched by usermod -l.
make_runtime_dir "$(id -u "$REMOTE_USER")" "$(id -g "$REMOTE_USER")"
