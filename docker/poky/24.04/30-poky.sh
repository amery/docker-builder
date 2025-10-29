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

# Find existing build directory
# If BUILDDIR already set (from run-hook.sh), use it
if [ -n "${BUILDDIR:-}" ]; then
	builddir="${BUILDDIR#$WS/}"
else
	# Get path relative to workspace
	x="${CURDIR#$WS/}"
	if [ "$x" != "$CURDIR" ]; then
		# We're inside workspace, extract first component
		x="${x%%/*}"
		# Check if it's a build directory with conf/local.conf
		if [ -s "$WS/$x/conf/local.conf" ]; then
			builddir="$x"
		fi
	fi

	# If not in a build directory, search for one
	if [ -z "${builddir:-}" ]; then
		x="$(ls -1d "$WS"/*[Bb]uild*/conf/local.conf 2>/dev/null | head -1)"
		if [ -n "$x" ]; then
			builddir="${x%/conf/local.conf}"
			builddir="${builddir#$WS/}"
		fi
	fi
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
