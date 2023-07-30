#!/bin/sh

set -eu

OS_V2=$(cut -d. -f1-2 /etc/alpine-release)

for GO in go /usr/local/bin/go-*; do
	GO_VERSION=$($GO version | sed -e 's|.* go\([1-9][^ ]\+\) .*|\1|')
	GO_V2=$(echo "$GO_VERSION" | cut -d. -f1-2)

	echo "multi-$GO_VERSION-alpine$OS_V2"
	echo "multi-$GO_V2-alpine$OS_V2"
done | sort -uV
