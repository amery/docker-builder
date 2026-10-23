#!/bin/sh

set -eu

# shellcheck disable=SC1091
. /etc/os-release

NODE_VERSION="$(node --version | sed -e 's/^v//')"
NODE_V2=$(echo "$NODE_VERSION" | cut -d. -f1-2)

echo "node$NODE_VERSION-ubuntu$VERSION_ID"
echo "node$NODE_V2-ubuntu$VERSION_ID"

# latest OS
echo "node$NODE_VERSION"
echo "node$NODE_V2"
