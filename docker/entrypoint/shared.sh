#!/bin/sh
#
# Shared entrypoint library, installed as
# /usr/local/lib/docker-builder/entrypoint.sh. Sourced (not executed)
# by the generated entrypoint.sh at container start and by
# devcontainer.sh at image build time.

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

# atomic_install <dest> <mode> <command...>
#
# Install <dest> atomically: capture the command's stdout into a
# temporary file beside <dest>, set <mode> on it, then rename it into
# place. A concurrent reader — a login sourcing a profile, a reattach
# exec'ing user-exec — therefore never sees a half-written file.
atomic_install() {
	local dest="$1" mode="$2" tmp="$1.$$"
	shift 2

	"$@" > "$tmp"
	chmod "$mode" "$tmp"
	mv "$tmp" "$dest"
}

# gen_profile
#
# Emit the assembled Z99 login profile to stdout: the PATH bootstrap
# followed by the output of every /etc/entrypoint.d plugin. The caller
# owns the output. The target profile is sourced by every login shell
# and re-entered by nested `su -`/`bash -l`, so the caller must redirect
# into a temporary file and rename it into place (atomic_install does
# exactly this) — never straight onto the live profile, which a
# concurrent or nested login could otherwise source half-written.
#
# The workspace bin is added two ways on purpose. The baked "${WS:-}"
# captures the value present when this runs: the entrypoint has WS in
# its environment and the later `su -` strips it, so baking is
# load-bearing there. The deferred "\${WS:-}" covers the devcontainer
# build, where WS is unset at build time but present in the login
# environment via containerEnv. path_prepend dedupes, so listing both
# is safe.
gen_profile() {
	local x

cat <<EOT
path_prepend() {
	local p
	for p; do
		[ -n "\$p" ] || continue
		case ":\$PATH:" in
		*":\$p:"*) : ;;
		*) export PATH="\$p:\$PATH" ;;
		esac
	done
}

for d in /opt/* "\$HOME/.local" "\$HOME" "${WS:-}" "\${WS:-}"; do
	if [ -n "\$d" -a -d "\$d/bin" ]; then
		path_prepend "\$d/bin"
	fi
done
EOT

	# the plugins are our own numbered NN-name.sh files — no exotic
	# names — and ls | sort -V gives the version-sorted order find
	# cannot
	# shellcheck disable=SC2012
	for x in $(ls -1 /etc/entrypoint.d/*.sh 2> /dev/null | sort -V); do
		[ -s "$x" ] || continue
		echo "# $x"
		# the plugins are discovered at runtime; nothing to follow at
		# lint time
		# shellcheck disable=SC1090
		. "$x"
	done

	printf '\nunset -f path_prepend\n'
}

# gen_user_exec
#
# Emit the complete run-as-user accessor to stdout: the shared
# prologue — shebang, the workspace identity baked for the container's
# life (USER_NAME, USER_UID, USER_GID, USER_HOME), the per-call
# argument handling ([-r] [-C dir] [--]) and the sudo-mode (-r)
# dispatch — followed by the drop-to-user dispatch skeleton, whose
# branch bodies come from handlers the sourcing entrypoint defines:
#
#   gen_user_exec_cmd    — emit the run-"$@"-as-$USER_NAME dispatch
#   gen_user_exec_login  — emit the interactive-login dispatch
#
# The entrypoint installs the result atomically at
# /usr/local/bin/user-exec. The identity is read from the entrypoint's
# environment here, exactly as gen_profile reads WS.
#
# The sudo-mode branch is shared because it is OS-independent:
# user-exec always starts as root — the one-shot dispatch and a
# `docker exec` reattach alike — and only the per-OS handlers drop
# privileges, so -r simply skips the drop. It adopts the workspace
# user's environment instead: their HOME, so the login shell sources
# their profile, plus the sudo-style identity context. SUDO_COMMAND is
# exported here, per invocation, never baked into the Z99 profile —
# that profile is sourced by every login in a persistent container, so
# a baked block would leak a frozen sudo context into non-sudo
# reattach sessions.
gen_user_exec() {
	cat <<EOT
#!/bin/sh

set -eu

USER_NAME='$USER_NAME'
USER_UID='$USER_UID'
USER_GID='$USER_GID'
USER_HOME='$USER_HOME'
EOT

	cat <<'EOT'

. /usr/local/lib/docker-builder/entrypoint.sh

ROOT= DIR=
while [ $# -gt 0 ]; do
	case "$1" in
	-r)	ROOT=1 ;;
	-C)	DIR="$2"; shift ;;
	--)	shift; break ;;
	*)	break ;;
	esac
	shift
done

: "${DIR:=$USER_HOME}"
[ -d "$DIR" ] || die "$DIR: no such directory"

if [ -n "$ROOT" ]; then
	# sudo mode: stay root, with the workspace user's environment
	export HOME="$USER_HOME"
	export SUDO_USER="$USER_NAME" SUDO_UID="$USER_UID" SUDO_GID="$USER_GID"
	export SUDO_COMMAND="${*:-/bin/bash}"

	if [ $# -gt 0 ]; then
		cd "$DIR" && exec /bin/bash -lc 'exec "$@"' user-exec "$@"
	else
		cd "$DIR" && exec /bin/bash -il
	fi
fi

if [ $# -gt 0 ]; then
EOT

	gen_user_exec_cmd

	echo "else"

	gen_user_exec_login

	echo "fi"
}
