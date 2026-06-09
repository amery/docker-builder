#!/bin/sh

set -eu

. /usr/local/lib/docker-builder/entrypoint.sh

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

if [ "x${1:-}" = "x--run-hook" ]; then
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
if [ "x${1:-}" = "x-N" ]; then
	IDLE=1
	shift
fi

[ "${USER_NAME:-root}" != "root" ] || die "Invalid \$USER_NAME (${USER_NAME})"

# create workspace-friendly user
addgroup -S -g "$USER_GID" "$USER_NAME"
adduser -s /bin/bash -S -h "$USER_HOME" \
	-G "$USER_NAME" -u "$USER_UID" \
	"$USER_NAME"

if [ $# -gt 0 ]; then
	CMD="$*"
else
	CMD=
fi

F=/etc/profile.d/Z99-docker-run.sh
T="$F.$$"
gen_profile > "$T"

# In sudo mode the login keeps its environment, so the SUDO_* context
# is exported from the profile. Append it to the temporary file before
# the rename, so the published profile is always complete and lands in
# a single atomic step instead of a second write onto the live file.
if [ -n "${USER_IS_SUDO:+yes}" ]; then
	cat <<-EOT >> "$T"

	export SUDO_COMMAND="${CMD:-/bin/bash}"
	export SUDO_USER=$USER_NAME
	export SUDO_UID=$USER_UID
	export SUDO_GID=$USER_GID
	EOT
fi

mv "$T" "$F"

# Generate the run-as-user accessor. The one-shot tail below and a
# `docker exec` reattach into a persistent container both dispatch
# through it, so the run-as-user path has a single definition. The
# heredoc is quoted: CURDIR, the command, USER_NAME, USER_HOME and
# USER_IS_SUDO are read at run time (per attach), not baked here.
cat > /usr/local/bin/user-exec <<'EOT'
#!/bin/sh

set -eu

. /usr/local/lib/docker-builder/entrypoint.sh

if [ $# -gt 0 ]; then
	LOGIN="cd '$CURDIR' && exec $*"
else
	LOGIN="cd '$CURDIR'; exec /bin/bash -il"
fi

if [ -n "${USER_IS_SUDO:+yes}" ]; then
	exec /bin/bash -lc "$LOGIN"
elif [ -t 0 ]; then
	# Interactive TTY: use su for a proper session
	exec su - "$USER_NAME" -c "$LOGIN"
else
	# Non-TTY: su-exec + login bash avoids the su- stdin hang.
	# env -i clears the environment like su - does; CURDIR survives
	# because it is baked into $LOGIN, not read from the env.
	# Resolve su-exec first: env -i wipes PATH, so a bare "su-exec"
	# is not found in env's default search path.
	SU_EXEC=$(command -v su-exec) || die "su-exec not found in PATH"
	exec env -i HOME="$USER_HOME" USER="$USER_NAME" \
		"$SU_EXEC" "$USER_NAME" /bin/bash -lc "$LOGIN"
fi
EOT
chmod 0755 /usr/local/bin/user-exec

# -N (persistent): init is done — hold the container open, but exit
# cleanly on `docker stop` (SIGTERM) so --rm removes it promptly
# instead of waiting out the stop timeout.
if [ -n "$IDLE" ]; then
	trap 'exit 0' TERM INT
	tail -f /dev/null & wait
	exit 0
fi

exec /usr/local/bin/user-exec "$@"
