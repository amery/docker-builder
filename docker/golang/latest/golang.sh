cat <<EOT
export GOPATH="${GOPATH:-$WS}"
export PATH="\$GOPATH/bin:/usr/local/go/bin:\$PATH"
export CGO_ENABLED=0
${GO111MODULE:+export GO111MODULE=${GO111MODULE}}
EOT
