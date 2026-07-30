# shellcheck shell=sh

# XDG_RUNTIME_DIR and its /run/user/$UID directory are established
# earlier: the profile prologue sets and exports the variable, and the
# entrypoint's make_runtime_dir (baked at build time for the devcontainer
# flow, which bypasses the entrypoint) owns the directory. All that
# remains here is gpg-specific — bridge the forwarded gpg-agent sockets
# into ~/.gnupg so tools using the legacy path find them.
#
# The heredoc runs at every login shell from the generated profile — the
# only hook the devcontainer flow has at runtime, since it sources these
# snippets at image build time, before the bind-mount exists.

cat <<'EOT'
if [ -d "$XDG_RUNTIME_DIR/gnupg" ]; then
	mkdir -p "$HOME/.gnupg"
	chmod 0700 "$HOME/.gnupg"
	for sock in "$XDG_RUNTIME_DIR/gnupg"/S.gpg-agent*; do
		[ -S "$sock" ] || continue
		ln -snf "$sock" "$HOME/.gnupg/${sock##*/}"
	done
fi
EOT
