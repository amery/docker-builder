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

# create workspace-friendly user
addgroup -S -g "$USER_GID" "$USER_NAME"
adduser -s /bin/bash -S -h "$USER_HOME" \
	-G "$USER_NAME" -u "$USER_UID" \
	"$USER_NAME"

# The Z99 profile holds environment only; the sudo-mode SUDO_* context
# is per-invocation and belongs to user-exec -r, never here, where every
# later login would re-source it.
atomic_install /etc/profile.d/Z99-docker-run.sh 0644 gen_profile

# gen_user_exec_cmd / gen_user_exec_login
# Dispatch handlers for the shared gen_user_exec generator: the Alpine
# drop-to-user branches (busybox su cannot forward argv, so commands go
# through su-exec; the TTY split on login is a busybox artefact too, so
# it nests here rather than in the shared skeleton).
gen_user_exec_cmd() {
	cat <<'EOT'
	# A command: su-exec preserves argv cleanly on busybox (busybox su
	# -c does not forward positional parameters reliably). env -i clears
	# the environment like su - does; TERM is kept so TTY commands work.
	# Resolve su-exec first: env -i wipes PATH, so a bare "su-exec" is
	# not found in env's default search path.
	SU_EXEC=$(command -v su-exec) || die "su-exec not found in PATH"
	exec env -i HOME="$USER_HOME" USER="$USER_NAME" ${TERM:+TERM="$TERM"} \
		"$SU_EXEC" "$USER_NAME" /bin/bash -lc 'dir="$1"; shift; cd "$dir" && exec "$@"' \
		user-exec "$DIR" "$@"
EOT
}

gen_user_exec_login() {
	cat <<'EOT'
	if [ -t 0 ]; then
		# Interactive login on a TTY: su - for a proper session. No
		# command, so DIR (a single path) can be quoted into the -c
		# string.
		exec su - "$USER_NAME" -c "cd '$DIR' && exec /bin/bash -il"
	else
		# Non-TTY login shell: su-exec, as for commands.
		SU_EXEC=$(command -v su-exec) || die "su-exec not found in PATH"
		exec env -i HOME="$USER_HOME" USER="$USER_NAME" \
			"$SU_EXEC" "$USER_NAME" /bin/bash -lc "cd '$DIR' && exec /bin/bash -il"
	fi
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
