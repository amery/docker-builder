#!/bin/sh

set -eu

# print the version names the published image reports, so aliases are
# named after what was pushed rather than a stale local copy
image_versions() {
	${DOCKER:-docker} run --rm --pull always "$1" --version
}

get_versions() {
	local image="$1" base= tag= versions=

	base="${image%:*}"

	if [ "$base" = "$image" ]; then
		tag=latest
		echo "$tag"
	else
		tag="${image##*:}"
	fi

	case "$image" in
	*gitpod*)
		# no entrypoint for --version
		echo "$tag"
		return
	esac

	# a plain assignment, so set -e aborts when the run fails
	versions="$(image_versions "$image")"

	for v in $versions; do
		if [ "$v" != "$tag" -a "$v" != "undefined" ]; then
			echo "$v"
		fi
	done
}

for x; do
	base="${x%:*}"
	versions="$(get_versions "$x")"

	for v in $(printf '%s\n' "$versions" | sort -uV); do
		echo "$base:$v"
	done
done
