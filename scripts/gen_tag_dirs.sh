#!/bin/sh

set -eu

find_base() {
	local x="$1"

	while true; do
		if [ -s "$x/Dockerfile" -o -s "$x/Dockerfile.in" ]; then
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
			n="docker-${n##*/}-builder"

			if [ "$d0" != "$d1" ]; then
				v0="${d1##*/}"
				d0="$n:$v0"
			fi

			echo "$n:$v $d0"
		fi
	done
}

# process docker dirs
#
find -L * -name 'Dockerfile' -o -name 'Dockerfile.in' |
	sed -e 's|/[^/]\+$||' | sort -uV |
	while read x; do
		tags "$x"
	done
