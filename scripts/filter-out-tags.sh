#!/bin/sh

WANTED="$1"
while read tag id; do
	case "$tag" in
	*:"<none>")
		echo "$id"
		;;
	*)
		pat=$(echo "$tag" | sed -e 's|\.|\\.|g')
		if ! grep -q "^$pat$" "$WANTED"; then
			echo "$tag"
		fi
		;;
	esac
done
