#!/bin/sh

set -eu

OS_V2=$(cut -d. -f1-2 /etc/alpine-release)

NODE_VERSION="$(node --version | sed -e 's/^v//')"
NPM_VERSION="$(npm info npm version)"

NODE_V2=$(echo "$NODE_VERSION" | cut -d. -f1-2)
NPM_V1=$(echo "$NPM_VERSION" | cut -d. -f1)

echo "$NODE_VERSION-npm$NPM_VERSION-alpine$OS_V2"
echo "$NODE_VERSION-npm$NPM_VERSION"
echo "$NODE_VERSION-npm$NPM_V1"
echo "$NODE_V2-npm$NPM_V1"
