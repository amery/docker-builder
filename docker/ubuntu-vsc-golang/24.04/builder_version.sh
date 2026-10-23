#!/bin/sh

set -eu

# shellcheck disable=SC1091
. /etc/os-release

GO_VERSION=$(go version | sed -e 's|.* go\([1-9][^ ]\+\) .*|\1|')
GO_V2=$(echo "$GO_VERSION" | cut -d. -f1-2)

echo "go$GO_VERSION-ubuntu$VERSION_ID"
echo "go$GO_V2-ubuntu$VERSION_ID"

# latest OS
echo "go$GO_VERSION"
echo "go$GO_V2"
