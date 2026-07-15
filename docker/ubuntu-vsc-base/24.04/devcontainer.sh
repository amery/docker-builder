#!/bin/sh

set -eu

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
