#!/bin/sh

set -eu

OS_V2=$(cut -d. -f1-2 /etc/alpine-release)

NODE_VERSION="$(node --version | sed -e 's/^v//')"
NPM_VERSION="$(npm info npm version)"
YARN_VERSION="$(yarn -version)"

NODE_V2=$(echo "$NODE_VERSION" | cut -d. -f1-2)
NODE_V1=$(echo "$NODE_VERSION" | cut -d. -f1)
YARN_V2=$(echo "$YARN_VERSION" | cut -d. -f1-2)
NPM_V2=$(echo "$NPM_VERSION" | cut -d. -f1-2)
NPM_V1=$(echo "$NPM_VERSION" | cut -d. -f1)

echo "$NODE_VERSION-npm$NPM_VERSION-yarn$YARN_VERSION-alpine$OS_V2"

echo "$NODE_V2-npm$NPM_V2-yarn$YARN_V2-alpine$OS_V2"
echo "$NODE_V2-npm$NPM_V2-yarn$YARN_V2"

echo "$NODE_V2-npm$NPM_V2-alpine$OS_V2"
echo "$NODE_V2-npm$NPM_V2"
echo "$NODE_V1-npm$NPM_V1"

echo "$NODE_V2-yarn$YARN_V2-alpine$OS_V2"
echo "$NODE_V2-yarn$YARN_V2"
