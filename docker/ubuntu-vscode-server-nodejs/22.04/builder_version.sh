#!/bin/sh

set -eu

. /etc/os-release

APP=vscode-server
APP_VERSION="$(dpkg -s code-server | sed -n 's|^Version: \([^-]\+\).*|\1|p')"
APP_V2=$(echo "$APP_VERSION" | cut -d. -f1-2)

NODE_VERSION="$(node --version | sed -e 's/^v//')"
NODE_V2=$(echo "$NODE_VERSION" | cut -d. -f1-2)
NODE_V1=$(echo "$NODE_VERSION" | cut -d. -f1)

echo "$APP$APP_VERSION-node$NODE_VERSION-ubuntu$VERSION_ID"
echo "$APP$APP_VERSION-node$NODE_V2-ubuntu$VERSION_ID"
echo "$APP$APP_V2-node$NODE_V2-ubuntu$VERSION_ID"
echo "$APP$APP_V2-node$NODE_V1-ubuntu$VERSION_ID"

# latest OS
echo "$APP$APP_V2-node$NODE_V2"
echo "$APP$APP_V2-node$NODE_V1"
