cat <<EOT
# Go
export GOPATH="\${GOPATH:-\${WS:-\$HOME/go}}"
[ "x\$GOPATH" = "\${WS:-}" ] || export PATH="\$GOPATH/bin:\$PATH"
export CGO_ENABLED=0
${GO111MODULE:+export GO111MODULE=${GO111MODULE}
}${GOINSECURE:+export GOINSECURE=${GOINSECURE}
}${GOPRIVATE:+export GOPRIVATE=${GOPRIVATE}
}
EOT
