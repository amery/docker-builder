# BUILDDIR
#
# Get path relative to workspace
x="${PWD#$WS/}"
if [ "$x" != "$PWD" ]; then
	# We're inside workspace, extract first component
	x="${x%%/*}"
	# Check if it's a build directory with conf/local.conf
	if [ -s "$WS/$x/conf/local.conf" ]; then
		BUILDDIR="$WS/$x"
	fi
fi

# If not in a build directory, search for one
if [ -z "${BUILDDIR:-}" ]; then
	x="$(ls -1d "$WS"/*[Bb]uild*/conf/local.conf 2>/dev/null | head -1)"
	if [ -n "$x" ]; then
		BUILDDIR="${x%/conf/local.conf}"
	fi
fi

# OEROOT
#
for x in \
	"$WS" "$WS/sources" \
	${BUILDDIR:+"$BUILDDIR/.."} \
	${BUILDDIR:+"$BUILDDIR/../sources"} \
	"$PWD" "$PWD/sources" \
	"$PWD/.." "$PWD/../sources" \
	; do
	for y in /poky ""; do
		if [ -s "$x$y/oe-init-build-env" ]; then
			OEROOT="$(cd "$x$y" && pwd)"
			break 2
		fi
	done
done

[ -d "${OEROOT:-}" ] || die "Invalid workspace, poky/oe-init-build-env not found."

# DL_DIR
#
[ -n "${DL_DIR:-}" ] || DL_DIR="$WS/downloads"
mkdir -p "$DL_DIR"

# Export for docker-builder-run
# These will be:
# 1. Passed to container via -e (because of LABEL)
# 2. DL_DIR will be mounted (because we set DOCKER_RUN_VOLUMES below)
export OEROOT BUILDDIR DL_DIR

# Request DL_DIR mounting
export DOCKER_RUN_VOLUMES="${DOCKER_RUN_VOLUMES:+$DOCKER_RUN_VOLUMES }DL_DIR"
