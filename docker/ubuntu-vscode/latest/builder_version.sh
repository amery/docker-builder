#!/bin/sh

dpkg -s code | sed -n 's|^Version: \([^-]\+\).*|\1|p'
