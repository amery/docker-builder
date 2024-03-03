#!/bin/sh

. /etc/os-release

APP=code-server
APP_VERSION="$(dpkg -s $APP | sed -n 's|^Version: \([^-]\+\).*|\1|p')"
APP_V2=$(echo "$APP_VERSION" | cut -d. -f1-2)

echo "$APP_VERSION-ubuntu$VERSION_ID"
echo "$APP_V2-ubuntu$VERSION_ID"

# latest OS
echo "$APP_VERSION"
echo "$APP_V2"
