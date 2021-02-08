#!/bin/sh

set -eu

get_versions() {
	local image="$1" base= tag=

	base="${image%:*}"

	if [ "$base" = "$image" ]; then
		tag=latest
		echo "$tag"
	else
		tag="${image##*:}"
	fi

	for v in $(${DOCKER:-docker} run "$image" --version); do
		if [ "x$v" != "x$tag" -a "x$x" != "undefined" ]; then
			echo "$v"
		fi
	done
}

for x; do
	base="${x%:*}"

	for v in $(get_versions "$x" | sort -uV); do
		echo "$base:$v"
	done
done
