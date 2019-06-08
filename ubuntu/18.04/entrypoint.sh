#!/bin/sh

set -eu

err() {
	if [ $# -eq 0 ]; then
		cat
	else
		echo "$*"
	fi | sed -e 's|^|E:|g' >&2
}

die() {
	err "$@"
	exit 1
}

[ "${USER_NAME:-root}" != "root" ] || die "Invalid \$USER_NAME (${USER_NAME})"

# create workspace-friendly user
groupadd -r -g "$USER_GID" "$USER_NAME"
useradd -r -g "$USER_GID" -u "$USER_UID" \
	-s /bin/bash -d "$USER_HOME" "$USER_NAME"

if [ ! -s "$USER_HOME/.profile" ]; then
	find /etc/skel ! -type d | while read f0; do
		f1="$USER_HOME/${f0##/etc/skel}"
		mkdir -p "${f1%/*}"
		cp -a "$f0" "$f1"
		chown "$USER_NAME:$USER_NAME" "$f1"
	done
	chown "$USER_NAME:$USER_NAME" "$USER_HOME"
fi

F=/etc/profile.d/Z99-docker-run.sh

cat <<EOT > "$F"
cd '$CURDIR'
EOT

if [ $# -gt 0 ]; then
	cat <<-EOT >> "$F"

	exec $*
	EOT
fi

grep -n ^ "$F"
su - "$USER_NAME"
