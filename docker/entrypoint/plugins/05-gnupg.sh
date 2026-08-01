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
# Set unconditionally, not only when a forward is mounted. Unlike the login
# snippets the other plugins emit, this runs as root at profile-generation
# time — container start for the entrypoint flow, image build time for the
# devcontainer flow — and at devcontainer build time no forward yet exists
# to key off. These builder images use gpg only through a forwarded agent,
# so suppressing autostart everywhere costs nothing; a container that truly
# wants a local agent can still start one with `gpgconf --launch gpg-agent`.
mkdir -p /etc/gnupg
if ! grep -qxF no-autostart /etc/gnupg/common.conf 2> /dev/null; then
	echo no-autostart >> /etc/gnupg/common.conf
fi
