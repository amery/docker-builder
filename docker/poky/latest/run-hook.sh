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
if [ -z "${DL_DIR:-}" ]; then
	x="$WS/downloads"
	if [ -L "$x" ]; then
		if y="$(readlink -m "$x")"; then
			x="$y"
		fi
	fi
	DL_DIR="$x"
fi
mkdir -p "$DL_DIR"
