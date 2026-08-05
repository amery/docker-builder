# shellcheck shell=sh

# Stop gpg from autostarting a local gpg-agent, so a forwarded host agent
# is never displaced. When a run.sh forwards the host's gpg-agent under
# $XDG_RUNTIME_DIR/gnupg, that directory is bind-mounted and its
# S.gpg-agent socket already sits at gpg's canonical agent-socket path, so
# gpg reaches the forwarded agent unaided. The hazard is the reverse: a gpg
# operation that finds the agent momentarily unreachable autostarts its own
# agent, which unlinks the bind-mounted socket to bind a fresh one —
# severing the forward, and holding none of the host's keys. no-autostart
# in /etc/gnupg/common.conf, the file every gnupg component reads, keeps a
# local agent from ever being spawned.
#
# The no-autostart write is a pure root side-effect at profile-generation
# time — container start for the entrypoint flow, image build time for the
# devcontainer flow — so it is set unconditionally, not only when a forward
# is mounted: the devcontainer build has no forward yet to key off, and
# these builder images use gpg only through a forwarded agent, so
# suppressing autostart everywhere costs nothing. A container that truly
# wants a local agent can still start one with `gpgconf --launch gpg-agent`.
mkdir -p /etc/gnupg
if ! grep -qxF no-autostart /etc/gnupg/common.conf 2> /dev/null; then
	echo no-autostart >> /etc/gnupg/common.conf
fi

# common.conf is only honoured from gnupg 2.4, so on 18.04/20.04/22.04 the
# setting above is inert. There the option has to reach ~/.gnupg/gpg.conf,
# which belongs to the user — so the Dockerfile seeds it through
# /etc/skel/.gnupg/gpg.conf, an initial default a new home picks up and
# the user is then free to change. Best effort by construction: a home
# that already exists never sees it. (Not 16.04: gnupg 1.4 treats an
# unknown option as fatal, so seeding it there breaks gpg outright.)
#
# Ownership and mode of the copied ~/.gnupg belong to the skel loop, not
# to this plugin: the loop mirrors /etc/skel/.gnupg, so the copy arrives
# 0700 and owned by the user.

# Older images bridged the forwarded sockets into ~/.gnupg with symlinks;
# this plugin no longer does, but a persistent home carried across an image
# swap keeps them. Under no-autostart a dangling link can no longer be
# repaired by an autostart, and a live one can redirect a launched local
# agent onto the forwarded socket — the kidnap no-autostart exists to
# prevent. Clear them at login, in the user's context: the -L guard takes
# only symlinks, never a live socket or a gnupg-managed redirect file.
cat <<'EOT'
for link in "$HOME/.gnupg"/S.gpg-agent*; do
	[ -L "$link" ] || continue
	rm -f "$link"
done
EOT
