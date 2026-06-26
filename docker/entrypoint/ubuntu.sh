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
	# su runs the login shell in a new session, which drops the
	# controlling terminal, so an interactive `bash -il` loses job
	# control under `docker -t`. Restore it per case below, but only on a
	# real TTY. Both launchers run the same payload: cd to $DIR (the
	# first positional) and exec the login bash. No `--` guard like the
	# command path's — these operands are fixed and never start with a
	# dash, so su has nothing to mis-permute.
	set -- -c 'cd "$1" && exec /bin/bash -il' user-exec "$DIR"

	if [ ! -t 0 ]; then
		# No TTY: job control is moot; the plain su below suffices.
		:
	elif su --help 2>&1 | grep -q -- --pty; then
		# util-linux su (20.04+): allocate a controlling pty for the
		# new session so bash regains job control.
		exec su --pty - "$USER_NAME" "$@"
	elif CHROOT=$(command -v chroot); then
		# shadow su (16.04/18.04) predates --pty: drop privileges in
		# place instead, keeping the session that owns the pty. env -i
		# mirrors `su -`'s clean login env; chroot is resolved first
		# because env -i empties PATH.
		exec env -i HOME="$USER_HOME" USER="$USER_NAME" ${TERM:+TERM="$TERM"} \
			"$CHROOT" --userspec="$USER_UID:$USER_GID" / /bin/sh "$@"
	fi

	# Fallback: no TTY, or a TTY whose su lacks --pty and has no chroot.
	exec su - "$USER_NAME" "$@"
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
