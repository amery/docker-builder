#!/bin/sh

set -eu

OWN="$1"
shift

TAB="$(printf '\t')"

. "$(dirname "$0")/common.in"

#
#
get_images() {
	cut -d' ' -f1 < "$1"
}

get_3rd_party() {
	local OWN="$1"
	local tag= dir= from= df=

	while read tag dir; do
		if [ ! -d "$dir" ]; then
			df=
		elif [ -s "$dir/Dockerfile.in" ]; then
			df="$dir/Dockerfile.in"
		else
			df="$dir/Dockerfile"
		fi

		if [ -n "$df" ]; then
			from="$(sed -n -e 's:^[ \t]*FROM[ \t]\+\([^ ]\+\).*$:\1:p' "$df")"
		else
			from="$dir"
		fi

		if [ -n "$from" ]; then
			if ! grep -q "^${from#*/} " "$OWN"; then
				echo "$from"
			fi
		fi
	done < "$OWN" | sort -uV
}

gen_image_files() {
	local dir="$1" x=
	shift

	(
	for x; do
		echo "$x"
	done

	find "$dir" ! -type d -a ! -name Dockerfile -a ! -name Dockerfile.in
	find "$dir" ! -type d -a -name '*.in' | sed -e 's|\.in$||'
	echo "$dir/Dockerfile"

	) | sed -e "s|^$PWD/||" -e "s|^./||" | sort -uV
}

key() {
	local x=
	for x; do
		echo "$x" | tr ':' '-'
	done
}

prefix() {
	local x=
	for x; do
		echo "\$(PREFIX)$(key $x)"
	done
}

pusher() {
	local x=
	for x; do
		echo "push-$(key $x)"
	done
}

puller() {
	local x=
	for x; do
		echo "pull-$(key $x)"
	done
}

sentinel() {
	local x=
	for x; do
		x="$(echo "$x" | tr ':/' '-_')"
		echo "\$(B)/.image-$x"
	done
}

IMAGES=$(get_images "$OWN")
IMAGES_SHORT=$(echo "$IMAGES" | sed -e 's|:.*||' | sort -uV)
THIRD_PARTY=$(get_3rd_party "$OWN")

cat <<EOT
# generated by $0
#
$(list_key_f IMAGES prefix $IMAGES_SHORT)
$(list_key_f PUSHERS pusher $IMAGES_SHORT)
$(list_key_f PULLERS puller $(sort_uV $IMAGES_SHORT $IMAGES $THIRD_PARTY))
$(list_key_f SENTINELS sentinel $(sort_uV $IMAGES_SHORT $IMAGES $THIRD_PARTY))
EOT

# THIRD_PARTY
#
for tag in $THIRD_PARTY; do
	s1="$(sentinel "$tag")"
	k1="$(key "$tag")"
	d1="$(puller "$tag")"
	cat <<EOT

# $tag
#
.PHONY: $k1 $d1
$k1: $s1
$d1: $s1

$s1: \$(IMAGE_MK)
	\$(DOCKER) pull $tag
	touch \$@
EOT
done

# OWN
#
while read tag dir; do
	if [ ! -d "$dir" ]; then
		df=
	elif [ -s "$dir/Dockerfile.in" ]; then
		df="$dir/Dockerfile.in"
	else
		df="$dir/Dockerfile"
	fi

	if [ -n "$df" ]; then
		from="$(sed -n -e 's:^[ \t]*FROM[ \t]\+\([^ ]\+\).*$:\1:p' "$df")"
	else
		from=$dir
		dir=
	fi

	if grep -q "^${from#*/} " "$OWN"; then
		s0=$(sentinel "${from#*/}")
	else
		s0=$(sentinel "$from")
	fi

	k1=$(key $tag)
	p1=$(pusher $tag)
	d1=$(puller $tag)
	s1=$(sentinel $tag)

	if [ -z "$dir" ]; then
		files=
	else
		from=
		files="$(gen_image_files "$dir" "$s0" '$(IMAGE_MK)')"
	fi

	cat <<EOT

# $tag
#
.PHONY: \$(PREFIX)$k1
\$(PREFIX)$k1: $s1

.PHONY: $p1
$p1: $s1
	\$(DOCKER) push \$(PREFIX)$tag

.PHONY: $d1
$d1:
	\$(DOCKER) pull \$(PREFIX)$tag

$(list_target $s1 $files)
EOT

if [ -d "$dir" ]; then
	echo "$TAB\$(DOCKER) build -t \$(PREFIX)$tag $dir"
else
	echo "$TAB\$(DOCKER) tag \$(PREFIX)$from \$(PREFIX)$tag"
fi
echo "${TAB}touch \$@"

done < "$OWN"

# shortcuts
#
for x in $IMAGES_SHORT; do

	k1=$(prefix $x)
	p1=$(pusher $x)
	d1=$(puller $x)
	s1=$(sentinel $x)

	sub="$(grep "$x:" "$OWN" | cut -d' ' -f1)"

	cat <<EOT

# $x
#
.PHONY: $k1
$k1: $s1

.PHONY: $p1 $d1
$(list_target_f $p1 pusher $sub)
$(list_target_f $d1 puller $sub)

$(list_target_f $s1 sentinel $sub)
	touch \$@
EOT
done
