# shellcheck shell=sh

# The runtime directory /run/user/$UID is created and owned by the
# workspace user in the entrypoint's make_runtime_dir — baked at image
# build time for the devcontainer flow, which bypasses the entrypoint —
# so this plugin no longer creates or chowns it. What remains is
# gpg-specific: point XDG_RUNTIME_DIR at the directory and bridge the
# forwarded gpg-agent sockets into ~/.gnupg so tools using the legacy
# path find them.
#
# The heredoc runs at every login shell from the generated profile — the
# only hook the devcontainer flow has at runtime, since it sources these
# snippets at image build time, before the bind-mount exists.

cat <<'EOT'
: ${XDG_RUNTIME_DIR:="/run/user/$(id -u)"}
if [ -d "$XDG_RUNTIME_DIR/gnupg" ]; then
	export XDG_RUNTIME_DIR
	mkdir -p "$HOME/.gnupg"
	chmod 0700 "$HOME/.gnupg"
	for sock in "$XDG_RUNTIME_DIR/gnupg"/S.gpg-agent*; do
		[ -S "$sock" ] || continue
		ln -snf "$sock" "$HOME/.gnupg/${sock##*/}"
	done
fi
EOT
