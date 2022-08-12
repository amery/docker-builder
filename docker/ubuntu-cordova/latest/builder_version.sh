#!/bin/sh

. /etc/os-release

APP_VERSION="$(npm info cordova version)"
APP_V2=$(echo "$APP_VERSION" | cut -d. -f1-2)

NODE_VERSION="$(dpkg -s nodejs | sed -n 's|^Version: \([^-]\+\).*|\1|p')"
NODE_V2=$(echo "$NODE_VERSION" | cut -d. -f1-2)

echo "$APP_VERSION-node$NODE_VERSION-ubuntu$VERSION_ID"
echo "$APP_VERSION-node$NODE_V2-ubuntu$VERSION_ID"
echo "$APP_V2-node$NODE_V2-ubuntu$VERSION_ID"

# latest OS
echo "$APP_VERSION-node$NODE_VERSION"
echo "$APP_VERSION-node$NODE_V2"
echo "$APP_V2-node$NODE_V2"
