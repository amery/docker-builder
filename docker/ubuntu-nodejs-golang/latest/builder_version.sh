#!/bin/sh

set -eu

. /etc/os-release

GO_VERSION=$(go version | sed -e 's|.* go\([1-9][^ ]\+\) .*|\1|')
NODE_VERSION="$(node --version | sed -e 's/^v//')"

GO_V2=$(echo "$GO_VERSION" | cut -d. -f1-2)
NODE_V2=$(echo "$NODE_VERSION" | cut -d. -f1-2)

echo "node$NODE_VERSION-go$GO_VERSION-ubuntu$VERSION_ID"
echo "node$NODE_V2-go$GO_V2-ubuntu$VERSION_ID"
