#!/bin/sh

set -eu

# the sourced runtime lib is absent at lint time
# shellcheck disable=SC1091
. /usr/local/lib/docker-builder/entrypoint.sh

if [ "${1:-}" = "--version" ]; then
	if [ -s /etc/builder_version ]; then
		cat /etc/builder_version
	elif [ -x /usr/local/bin/builder_version ]; then
		exec /usr/local/bin/builder_version
	else
		echo "undefined"
	fi
	exit
fi

if [ "${1:-}" = "--run-hook" ]; then
	if [ -s /usr/local/share/docker-builder/run-hook.sh ]; then
		cat /usr/local/share/docker-builder/run-hook.sh
	else
		exit 1
	fi
	exit
fi

# -N: run init only, then idle — keeps a persistent container open
# (PID 1) for `docker exec` reattach instead of running a command.
IDLE=
if [ "${1:-}" = "-N" ]; then
	IDLE=1
	shift
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
	groupadd -g "$USER_GID" "$USER_NAME"
fi

if x=$(find_user_by_uid "$USER_UID"); then
	usermod -g "$USER_GID" \
		-s /bin/bash -d "$USER_HOME" -l "$USER_NAME" \
		"$x"
else
	useradd -g "$USER_GID" -u "$USER_UID" \
		-s /bin/bash -d "$USER_HOME" "$USER_NAME"
fi

if [ ! -s "$USER_HOME/.profile" ]; then
	find /etc/skel ! -type d | while read -r f0; do
		f1="$USER_HOME/${f0##/etc/skel}"
		mkdir -p "${f1%/*}"
		cp -a "$f0" "$f1"
		chown "$USER_NAME:$USER_NAME" "$f1"
	done
	chown "$USER_NAME:$USER_NAME" "$USER_HOME"
fi

# The Z99 profile holds environment only; the sudo-mode SUDO_* context
# is per-invocation and belongs to user-exec -r, never here, where every
# later login would re-source it.
atomic_install /etc/profile.d/Z99-docker-run.sh 0644 gen_profile

# gen_user_exec_cmd / gen_user_exec_login
# Dispatch handlers for the shared gen_user_exec generator: the Ubuntu
# drop-to-user branches, both via util-linux su -.
gen_user_exec_cmd() {
	cat <<'EOT'
	# `--` stops su's option scanning: util-linux su permutes operands,
	# so a command argument like `-un` would otherwise be read as a su
	# option. After it, $0=user-exec, $1=$DIR, $2.. = the command.
	exec su - "$USER_NAME" -c 'dir="$1"; shift; cd "$dir" && exec "$@"' -- user-exec "$DIR" "$@"
EOT
}

gen_user_exec_login() {
	cat <<'EOT'
	# util-linux su runs the login shell in a new session, dropping the
	# controlling terminal, so an interactive `bash -il` loses job
	# control under `docker -t`. --pty makes su allocate a controlling
	# pty and restores it. Prepend it on a real TTY (piped logins want
	# no pty) when su supports it; the shadow su on 16.04/18.04 lacks it.
	set -- - "$USER_NAME" -c 'cd "$1" && exec /bin/bash -il' -- user-exec "$DIR"
	if [ -t 0 ] && su --help 2>&1 | grep -q -- --pty; then
		set -- --pty "$@"
	fi
	exec su "$@"
EOT
}

# Generate the run-as-user accessor: user-exec [-r] [-C dir] [--] [cmd...]
# The one-shot dispatch at the end of this script and a `docker exec`
# reattach both go through it. atomic_install writes it via a temporary
# file + rename, so a concurrent reattach never execs a half-written
# accessor.
atomic_install /usr/local/bin/user-exec 0755 gen_user_exec

# -N (persistent): init is done — hold the container open, but exit
# cleanly on `docker stop` (SIGTERM) so --rm removes it promptly
# instead of waiting out the stop timeout.
if [ -n "$IDLE" ]; then
	trap 'exit 0' TERM INT
	tail -f /dev/null & wait
	exit 0
fi

exec /usr/local/bin/user-exec ${USER_IS_SUDO:+-r} -C "$CURDIR" -- "$@"
