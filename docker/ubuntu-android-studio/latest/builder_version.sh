#!/bin/sh

. /etc/os-release

read STUDIO_VERSION < /opt/android-sdk/android-studio/.version
VSCODE_VERSION="$(dpkg -s code | sed -n 's|^Version: \([^-]\+\).*|\1|p')"

STUDIO_V3=$(echo "$STUDIO_VERSION" | cut -d. -f1-3)
STUDIO_V2=$(echo "$STUDIO_VERSION" | cut -d. -f1-2)

VSCODE_V2=$(echo "$VSCODE_VERSION" | cut -d. -f1-2)

echo "$STUDIO_VERSION-vscode$VSCODE_VERSION-ubuntu$VERSION_ID"
echo "$STUDIO_V3-vscode$VSCODE_V2-ubuntu$VERSION_ID"
echo "$STUDIO_V2-vscode$VSCODE_V2-ubuntu$VERSION_ID"

# latest OS
echo "$STUDIO_VERSION-vscode$VSCODE_VERSION"
echo "$STUDIO_V3-vscode$VSCODE_V2"
echo "$STUDIO_V2-vscode$VSCODE_V2"
