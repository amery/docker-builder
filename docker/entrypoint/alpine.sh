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
addgroup -S -g "$USER_GID" "$USER_NAME"
adduser -s /bin/bash -S -h "$USER_HOME" \
	-G "$USER_NAME" -u "$USER_UID" \
	"$USER_NAME"

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
elif [ -t 0 ]; then
	# Interactive TTY: use su for proper session
	set -- su - "$USER_NAME"
else
	# Non-TTY: use su-exec with bash to avoid stdin issues
	# env -i clears environment like su - does
	set -- su-exec "$USER_NAME" /bin/bash -l
	set -- env -i HOME="$USER_HOME" USER="$USER_NAME" "$@"
fi

cat <<EOT >> "$F"

cd '$CURDIR'
${CMD:+exec $CMD}
EOT

"$@"
