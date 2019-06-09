# environment
#
BB_ENV_EXTRAWHITE="${BB_ENV_EXTRAWHITE:+$BB_ENV_EXTRAWHITE }DL_DIR"
for x in MACHINE DISTRO TCLIBC DL_DIR BB_ENV_EXTRAWHITE; do
	v="$(eval "echo \"\${$x:-}\"")"
	if [ -n "$v" ]; then
		echo "export $x='$v'"
	fi
done

# builddir
#
if [ -x "$WS/setup-environment" ]; then
	build_env="setup-environment"
else
	build_env="${OEROOT#$WS/}/oe-init-build-env"
fi

# find existing build directory
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

if [ -z "${builddir:-}" -a "$CURDIR" != "$WS" ]; then
	# or a new
	builddir="$(echo "${CURDIR#$WS/}" | sed -n -e 's:\(^[^/]*build[^/]*\).*:\1:p')"
fi

cat <<EOT
cd '$WS'
OEROOT='$OEROOT' source $build_env${builddir:+ '$builddir'}
EOT
