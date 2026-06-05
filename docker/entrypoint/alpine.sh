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

# Per-invocation navigation and command. Kept OUT of the sourced
# profile above so a `docker exec` login shell into a persistent
# container lands at its own CURDIR and runs its own command,
# instead of inheriting the values frozen at container start.
if [ -n "$CMD" ]; then
	LOGIN="cd '$CURDIR' && exec $CMD"
else
	LOGIN="cd '$CURDIR'; exec /bin/bash -il"
fi

if [ -n "${USER_IS_SUDO:+yes}" ]; then
	exec /bin/bash -lc "$LOGIN"
elif [ -t 0 ]; then
	# Interactive TTY: use su for proper session
	exec su - "$USER_NAME" -c "$LOGIN"
else
	# Non-TTY: use su-exec with bash to avoid stdin issues.
	# env -i clears environment like su - does; CURDIR survives
	# because it is baked into $LOGIN, not read from the env.
	# Resolve su-exec to an absolute path first: env -i wipes PATH,
	# so a bare "su-exec" is not found in env's default search path.
	SU_EXEC=$(command -v su-exec) || die "su-exec not found in PATH"
	exec env -i HOME="$USER_HOME" USER="$USER_NAME" \
		"$SU_EXEC" "$USER_NAME" /bin/bash -lc "$LOGIN"
fi
