#!/bin/sh

set -eu

. /etc/os-release

APP=vscode
APP_VERSION="$(dpkg -s vscode | sed -n 's|^Version: \([^-]\+\).*|\1|p')"

NODE_VERSION="$(node --version | sed -e 's/^v//')"
NPM_VERSION="$(npm info npm version)"
YARN_VERSION="$(yarn -version)"

NODE_V2=$(echo "$NODE_VERSION" | cut -d. -f1-2)
YARN_V2=$(echo "$YARN_VERSION" | cut -d. -f1-2)
NPM_V2=$(echo "$NPM_VERSION" | cut -d. -f1-2)
NPM_V1=$(echo "$NPM_VERSION" | cut -d. -f1)

echo "$APP$APP_VERSION-node$NODE_VERSION-npm$NPM_V2-yarn$YARN_V2-ubuntu$VERSION_ID"

echo "$APP$APP_VERSION-node$NODE_V2-npm$NPM_V2-yarn$YARN_V2-ubuntu$VERSION_ID"
echo "$APP$APP_V2-node$NODE_V2-npm$NPM_V2-yarn$YARN_V2"

echo "$APP$APP_VERSION-node$NODE_V2-npm$NPM_V2-ubuntu$VERSION_ID"
echo "$APP$APP_VERSION-node$NODE_V2-npm$NPM_V2"
echo "$APP$APP_VERSION-node$NODE_V2-npm$NPM_V1"

echo "$APP$APP_VERSION-node$NODE_V2-yarn$YARN_V2-ubuntu$VERSION_ID"
echo "$APP$APP_VERSION-node$NODE_V2-yarn$YARN_V2"
