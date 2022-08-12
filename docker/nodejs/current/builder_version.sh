#!/bin/sh

set -eu

OS_V2=$(cut -d. -f1-2 /etc/alpine-release)

NODE_VERSION="$(node --version | sed -e 's/^v//')"
NODE_V2=$(echo "$NODE_VERSION" | cut -d. -f1-2)
NODE_V1=$(echo "$NODE_VERSION" | cut -d. -f1)

echo "$NODE_VERSION-alpine$OS_V2"
echo "$NODE_V2-alpine$OS_V2"
echo "$NODE_V2"
echo "$NODE_V1"
