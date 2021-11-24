cat <<EOT

export GOPATH="${GOPATH:-$WS}"
export PATH="/usr/local/go/bin:\$PATH"
[ "x$GOPATH" = "x$WS" ] || export PATH="\$GOPATH/bin:\$PATH"
export CGO_ENABLED=0
${GO111MODULE:+export GO111MODULE=${GO111MODULE}
}${GOINSECURE:+export GOINSECURE=${GOINSECURE}
}${GOPRIVATE:+export GOPRIVATE=${GOPRIVATE}
}
EOT
