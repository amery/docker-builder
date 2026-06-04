#!/bin/sh

set -eu

REMOTE_USER="$1"
REMOTE_USER_HOME="$2"

err() {
	if [ $# -eq 0 ]; then
		cat
	else
		echo "$*"
	fi | sed -e 's|^|E: |' >&2
}

die() {
	err "$@"
	exit 1
}

#
# user's env
#
F="/etc/profile.d/Z99-devcontainer.sh"
T="$F.$$"
trap "rm -f $T" EXIT

# PATH
cat <<EOT > "$T"
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

for d in /opt/* "\$HOME/.local" "\$HOME" "\${WS:-}"; do
	if [ -n "\$d" -a -d "\$d/bin" ]; then
		path_prepend "\$d/bin"
	fi
done
EOT

# entrypoint scripts
ls -1 /etc/entrypoint.d/*.sh 2> /dev/null | sort -V |
	while read f; do
		echo "# $f"
		. "$f"
	done >> "$T"

cat <<EOT >> "$T"

unset -f path_prepend
EOT

mv "$T" "$F"
trap '' EXIT

if [ "$REMOTE_USER" != "vscode" ]; then
	# user's $HOME
	[ -n "$REMOTE_USER_HOME" ] || REMOTE_USER_HOME="/home/$REMOTE_USER"

	groupmod -n "$REMOTE_USER" vscode
	usermod -s /bin/bash -l "$REMOTE_USER" vscode
	if [ "$REMOTE_USER_HOME" != "/home/vscode" ]; then
		usermod -d "$REMOTE_USER_HOME" "$REMOTE_USER"
		mv /home/vscode "$REMOTE_USER_HOME"
	fi
fi
