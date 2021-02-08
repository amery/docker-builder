#!/bin/sh

. /etc/os-release

APP_VERSION="$(npm info cordova version)"
NODE_VERSION="$(dpkg -s nodejs | sed -n 's|^Version: \([^-]\+\).*|\1|p')"

echo "$APP_VERSION-node$NODE_VERSION-ubuntu$VERSION_ID"
echo "${APP_VERSION%.*}-node${NODE_VERSION%.*}-ubuntu$VERSION_ID"
echo "${APP_VERSION%%.*}-node${NODE_VERSION%%.*}-ubuntu$VERSION_ID"
