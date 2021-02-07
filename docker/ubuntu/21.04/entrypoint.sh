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

if [ "x${1:-}" = "x--version" ]; then
	if [ -s /etc/builder_version ]; then
		cat /etc/builder_version
	elif [ -x /usr/local/bin/builder_version ]; then
		exec /usr/local/bin/builder_version
	else
		echo "undefined"
	fi
	exit
fi

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

for x in /etc/entrypoint.d/*.sh; do
	[ -s "$x" ] || continue
	. "$x"
done > "$F"

if [ $# -gt 0 ]; then
	CMD="$*"
else
	CMD=
fi

if [ -n "${USER_IS_SUDO:+yes}" ]; then
	set -- /bin/bash -l

	cat <<-EOT >> "$F"
	export SUDO_COMMAND="${CMD:-/bin/bash}"
	export SUDO_USER=$USER_NAME
	export SUDO_UID=$USER_UID
	export SUDO_GID=$USER_GID
	EOT
else
	set -- su - "$USER_NAME"
fi

cat <<EOT >> "$F"

[ ! -d "\$HOME/bin" ] || export PATH="\$HOME/bin:\$PATH"
[ ! -d "\$HOME/.local/bin" ] || export PATH="\$HOME/.local/bin:\$PATH"

cd '$CURDIR'
${CMD:+exec $CMD}
EOT

"$@"
