#!/bin/sh

. /etc/os-release

APP=code
APP_VERSION="$(dpkg -s $APP | sed -n 's|^Version: \([^-]\+\).*|\1|p')"

echo "$APP_VERSION-ubuntu$VERSION_ID"
