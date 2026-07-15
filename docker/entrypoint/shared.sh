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

# ambient_caps_table
#
# Echo the Linux capability names indexed by bit position — a stable
# kernel ABI (position 0 = CAP_CHOWN, 21 = CAP_SYS_ADMIN, …). setpriv(1)
# names caps without the CAP_ prefix, so these double as its arguments.
ambient_caps_table() {
	echo chown dac_override dac_read_search fowner fsetid kill setgid \
		setuid setpcap linux_immutable net_bind_service net_broadcast \
		net_admin net_raw ipc_lock ipc_owner sys_module sys_rawio \
		sys_chroot sys_ptrace sys_pacct sys_admin sys_boot sys_nice \
		sys_resource sys_time sys_tty_config mknod lease audit_write \
		audit_control setfcap mac_override mac_admin syslog wake_alarm \
		block_suspend audit_read perfmon bpf checkpoint_restore
}

# ambient_bounding_set
#
# Echo this process's capability bounding set as a decimal number. The
# entrypoint and user-exec both read it while still root, before the
# drop, so it reflects what `docker run` granted the container.
ambient_bounding_set() {
	local h
	h=$(sed -n 's/^CapBnd:[[:space:]]*//p' /proc/self/status 2> /dev/null)
	echo "$(( 0x${h:-0} ))"
}

# ambient_present_caps <mask>
#
# Echo, one per line, the capability names whose bit is set in <mask>.
ambient_present_caps() {
	local mask="$1" i=0 name
	for name in $(ambient_caps_table); do
		[ $(( (mask >> i) & 1 )) -eq 0 ] || echo "$name"
		i=$(( i + 1 ))
	done
}

# ambient_known_cap <name>
#
# Succeed when <name> is a capability the kernel ABI table knows.
ambient_known_cap() {
	case " $(ambient_caps_table) " in
	*" $1 "*) return 0 ;;
	*) return 1 ;;
	esac
}

# ambient_have_setpriv
#
# Succeed only for a setpriv(1) that supports --ambient-caps. busybox's
# applet lacks it; util-linux's has carried it since 2.31.
ambient_have_setpriv() {
	command -v setpriv > /dev/null 2>&1 || return 1
	setpriv --help 2>&1 | grep -q -- '--ambient-caps'
}

# ambient_setpriv_prefix
#
# Echo a setpriv(1) command prefix that raises the operator-requested
# capabilities into the workspace user's ambient set, so a capability
# added at `docker run` with --cap-add survives the drop from root to the
# unprivileged user — the setuid transition would otherwise clear it. The
# prefix keeps the existing su/su-exec drop intact: setpriv stays root,
# sets the securebit that stops the setuid fixup plus the inheritable and
# ambient sets, then execs the drop, and the capability lands in the
# user's effective set. Echo nothing when there is nothing to raise.
#
# Which caps to raise:
#   USER_AMBIENT_CAPS unset          auto-detect — every cap in the
#                                    bounding set beyond Docker's default
#   USER_AMBIENT_CAPS "a,b"          exactly those (CAP_ prefix optional)
#   USER_AMBIENT_CAPS ""|none|-      nothing; feature off
#
# A requested cap not in the bounding set is skipped with a warning
# (raise what is grantable). When caps are wanted but setpriv(1) cannot
# deliver them, an explicit request is fatal — it returns non-zero so the
# caller's `set -e` aborts — while an auto-detected one only warns, the
# intent there being inferred rather than stated.
ambient_setpriv_prefix() {
	# Docker's default bounding set — chown dac_override fowner fsetid
	# kill setgid setuid setpcap net_bind_service net_raw sys_chroot
	# mknod audit_write setfcap. Caps beyond it were added by --cap-add.
	local default=0xa80425fb explicit= want bnd present name caps=

	case "${USER_AMBIENT_CAPS-@auto@}" in
	'@auto@')
		bnd=$(ambient_bounding_set)
		want=$(ambient_present_caps "$(( bnd & ~default ))")
		;;
	'' | none | -)
		return 0
		;;
	*)
		explicit=1
		want=$(printf '%s' "$USER_AMBIENT_CAPS" | tr 'A-Z,' 'a-z ' |
			sed -e 's/cap_//g')
		bnd=$(ambient_bounding_set)
		;;
	esac

	[ -n "$want" ] || return 0

	present=" $(ambient_present_caps "$bnd" | tr '\n' ' ') "
	for name in $want; do
		case "$present" in
		*" $name "*)
			caps="${caps:+$caps,}+$name"
			;;
		*)
			if ambient_known_cap "$name"; then
				err "ambient: '$name' not in the container bounding set; skipping"
			else
				err "ambient: unknown capability '$name'; skipping"
			fi
			;;
		esac
	done

	[ -n "$caps" ] || return 0

	if ! ambient_have_setpriv; then
		err "ambient: setpriv --ambient-caps unavailable; cannot grant $caps"
		[ -z "$explicit" ] || return 1
		return 0
	fi

	printf 'setpriv --securebits +no_setuid_fixup --inh-caps %s --ambient-caps %s --' \
		"$caps" "$caps"
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

# Elevate operator-added capabilities into the workspace user's ambient
# set so they survive the drop below (empty when none are requested).
# Read while still root, before the drop. An explicit but ungrantable
# request returns non-zero, so this assignment aborts under set -e; the
# per-OS drop lines expand $AMBIENT_PREFIX unquoted to build the argv.
AMBIENT_PREFIX=$(ambient_setpriv_prefix)

if [ $# -gt 0 ]; then
EOT

	gen_user_exec_cmd

	echo "else"

	gen_user_exec_login

	echo "fi"
}
