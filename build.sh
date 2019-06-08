#!/bin/sh

TAG_BASE="$USER/"

set -eu

BASE="$(dirname "$(readlink -f "$0")")"

if [ $# -eq 0 ]; then
	# detect docker dirs, following symlinks to catch soft tags
	set -- $(find -L -name 'Dockerfile')
fi

# working area
#
TMPDIR="$0.$$"
on_exit() {
	rm -rf "$TMPDIR"
}
trap on_exit EXIT INT

rm -rf "$TMPDIR"
mkdir "$TMPDIR"

find_base() {
	local x="$1"

	while true; do
		if [ -s "$x/Dockerfile" ]; then
			echo "$x"
		elif [ "${x:-/}" != "/" ]; then
			x="${x%/*}"
			continue
		fi
		break
	done
}

tags() {
	local x= v=
	local d0= d1=

	for x; do
		d0="$(find_base "$(realpath -es "$x")")"
		if [ ! -d "$d0" ]; then
			echo "$x: Invalid docker dir" >&2
		else
			v="${d0##*/}"
			d1="$(readlink -f "$d0")"
			n="${d1%/*}"
			n="${TAG_BASE:-}docker-${n##*/}-builder"

			echo "$n:$v $d0"
		fi
	done
}

# process docker dirs
#
for x; do
	if [ -d "$x/" -a -s "$x/Dockerfile" ]; then
		x="$x/Dockerfile"
	elif [ -d "$x" -o ! -s "$x" ]; then
		echo "$x: Invalid docker dir" >&2
		continue
	fi

	tags "$x"
done | tee "$TMPDIR/tag-dirs" | while read tag dir; do
	parent=$(sed -n -e 's:^[ \t]*FROM[ \t]\+\([^ ]\+\).*$:\1:p' "$dir/Dockerfile")

	echo "$tag${parent:+ $parent}"
done | tsort | tac | while read tag; do
	dir="$(grep "^$tag " "$TMPDIR/tag-dirs" | cut -d' ' -f2-)"
	if [ -d "$dir" ]; then
		cat <<-EOT
		#
		# $tag ($dir)
		#
		EOT
		docker build --rm -t "$tag" "$dir"
	fi
done
