#!/bin/sh

set -eu
cd "$(dirname "$0")"
exec docker build --rm -t amery/node .
