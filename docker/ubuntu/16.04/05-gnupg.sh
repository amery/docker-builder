# When /run/user/$UID/gnupg is bind-mounted from the host, docker
# auto-creates the parent /run/user/$UID as root:root 0755. Fix it
# for XDG_RUNTIME_DIR semantics and link the gpg-agent sockets into
# ~/.gnupg so tools using the legacy path find them.
#
# Root-time runs at container start in the docker-builder-run flow.
# The heredoc below runs at every login shell from the generated
# profile script; the devcontainer flow relies on it (with sudo)
# because snippets are sourced at image build time, before the
# bind-mount exists.
#
# USER_UID is guarded because devcontainer.sh sources snippets
# under set -eu without that variable defined.

if [ -n "${USER_UID:-}" ]; then
	RUN_USER_DIR="/run/user/$USER_UID"
	if [ -d "$RUN_USER_DIR/gnupg" ]; then
		chmod 0700 "$RUN_USER_DIR"
		chown "$USER_UID:$USER_GID" "$RUN_USER_DIR"
	fi
	unset RUN_USER_DIR
fi

cat <<'EOT'
: ${XDG_RUNTIME_DIR:="/run/user/$(id -u)"}
if [ -d "$XDG_RUNTIME_DIR/gnupg" ]; then
	export XDG_RUNTIME_DIR
	if [ "$(stat -c %u "$XDG_RUNTIME_DIR" 2>/dev/null)" != "$(id -u)" ]; then
		sudo -n chown "$(id -u):$(id -g)" "$XDG_RUNTIME_DIR" 2>/dev/null || true
		sudo -n chmod 0700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
	fi
	mkdir -p "$HOME/.gnupg"
	chmod 0700 "$HOME/.gnupg"
	for sock in "$XDG_RUNTIME_DIR/gnupg"/S.gpg-agent*; do
		[ -S "$sock" ] || continue
		ln -snf "$sock" "$HOME/.gnupg/${sock##*/}"
	done
fi
EOT
