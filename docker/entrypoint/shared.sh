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

# gen_profile
#
# Emit the assembled Z99 login profile to stdout: the PATH bootstrap
# followed by the output of every /etc/entrypoint.d plugin. The caller
# owns the output. The target profile is sourced by every login shell
# and re-entered by nested `su -`/`bash -l`, so the caller must redirect
# into a temporary file and rename it into place — never straight onto
# the live profile, which a concurrent or nested login could otherwise
# source half-written.
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

	for x in $(ls -1 /etc/entrypoint.d/*.sh 2> /dev/null | sort -V); do
		[ -s "$x" ] || continue
		echo "# $x"
		. "$x"
	done

	printf '\nunset -f path_prepend\n'
}
