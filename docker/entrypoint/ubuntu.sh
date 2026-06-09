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
	find /etc/skel ! -type d | while read f0; do
		f1="$USER_HOME/${f0##/etc/skel}"
		mkdir -p "${f1%/*}"
		cp -a "$f0" "$f1"
		chown "$USER_NAME:$USER_NAME" "$f1"
	done
	chown "$USER_NAME:$USER_NAME" "$USER_HOME"
fi

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
# heredoc is quoted: CURDIR, the command, USER_NAME and USER_IS_SUDO
# are read at run time (per attach), not baked here.
cat > /usr/local/bin/user-exec <<'EOT'
#!/bin/sh

set -eu

if [ $# -gt 0 ]; then
	LOGIN="cd '$CURDIR' && exec $*"
else
	LOGIN="cd '$CURDIR'; exec /bin/bash -il"
fi

if [ -n "${USER_IS_SUDO:+yes}" ]; then
	exec /bin/bash -lc "$LOGIN"
else
	exec su - "$USER_NAME" -c "$LOGIN"
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
