#!/bin/sh

OS_V2=$(cut -d. -f1-2 /etc/alpine-release)

GO_VERSION=$(go version | sed -e 's|.* go\([1-9][^ ]\+\) .*|\1|')
GO_V2=$(echo "$GO_VERSION" | cut -d. -f1-2)

echo "$GO_VERSION-alpine$OS_V2"
echo "$GO_V2-alpine$OS_V2"
