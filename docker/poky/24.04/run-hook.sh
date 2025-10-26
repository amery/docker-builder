# BUILDDIR
#
x="$(pwd)"
while true; do
	if [ -s "$x/conf/local.conf" ]; then
		BUILDDIR="$x"
		break
	elif [ "$WS" = "${x:-/}" ]; then
		break
	fi

	x="${x%/*}"
done

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
