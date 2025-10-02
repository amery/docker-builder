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

# helper to find existing group by GID
find_group_by_gid() {
	local name
	name=$(cut -d: -f1,3 /etc/group | grep ":$1$" | cut -d: -f1)
	[ -n "$name" ] || return 1
	echo "$name"
}

# helper to find existing user by UID
find_user_by_uid() {
	local name
	name=$(cut -d: -f1,3 /etc/passwd | grep ":$1$" | cut -d: -f1)
	[ -n "$name" ] || return 1
	echo "$name"
}

# create workspace-friendly user
if x=$(find_group_by_gid "$USER_GID"); then
	groupmod -n "$USER_NAME" "$x"
else
	groupadd -r -g "$USER_GID" "$USER_NAME"
fi

if x=$(find_user_by_uid "$USER_UID"); then
	usermod -g "$USER_GID" \
		-s /bin/bash -d "$USER_HOME" -l "$USER_NAME" \
		"$x"
else
	useradd -r -g "$USER_GID" -u "$USER_UID" \
		-s /bin/bash -d "$USER_HOME" "$USER_NAME"
fi

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
for d in /opt/* "\$HOME/.local" "\$HOME" "$WS"; do
	if [ -n "\$d" -a -d "\$d/bin" ]; then
		export PATH="\$d/bin:\$PATH"
	fi
done
EOT

for x in $(ls -1 /etc/entrypoint.d/*.sh 2> /dev/null | sort -V); do
	[ -s "$x" ] || continue
	. "$x"
done >> "$F"

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

cd '$CURDIR'
${CMD:+exec $CMD}
EOT

"$@"
