# This file is sourced by base entrypoint as /etc/entrypoint.d/30-poky.sh
# Its OUTPUT (via echo/cat) is appended to the profile file
# OEROOT, DL_DIR, BUILDDIR, WS, CURDIR are all available

# BB environment whitelist
BB_ENV_PASSTHROUGH_ADDITIONS="${BB_ENV_PASSTHROUGH_ADDITIONS:+$BB_ENV_PASSTHROUGH_ADDITIONS }DL_DIR"

# Export OE variables
for x in MACHINE DISTRO TCLIBC DL_DIR BB_ENV_PASSTHROUGH_ADDITIONS; do
	v="$(eval "echo \"\${$x:-}\"")"
	if [ -n "$v" ]; then
		echo "export $x='$v'"
	fi
done

# Find existing build directory from CURDIR
x="$CURDIR"
while true; do
	if [ -s "$x/conf/local.conf" ]; then
		builddir="${x#$WS/}"
		break
	elif [ "$WS" = "${x:-/}" ]; then
		break
	fi

	x="${x%/*}"
done

# If not found and we're in a potential builddir, extract it
if [ -z "${builddir:-}" -a "$CURDIR" != "$WS" ]; then
	builddir="$(echo "${CURDIR#$WS/}" | sed -n -e 's:\(^[^/]*build[^/]*\).*:\1:p')"
fi

# Setup OE/BitBake environment (replicate oe-buildenv-internal essentials)
# This avoids verbose output from oe-init-build-env
cat <<EOT
cd '$WS'
export OEROOT='$OEROOT'
${builddir:+export BUILDDIR='$WS/$builddir'}
${builddir:+export BBPATH='$WS/$builddir'}
export PYTHONPATH="$OEROOT/bitbake/lib:\${PYTHONPATH:-}"
export PATH="$OEROOT/bitbake/bin:$OEROOT/scripts:\$PATH"
${builddir:+cd '$builddir'}
EOT
