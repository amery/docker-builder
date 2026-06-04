# Resolve the Go toolchain root so the login PATH points at wherever Go
# lives. Prefer a pinned GOROOT; else ask go when it is on PATH; else scan
# the usual install prefixes (the official golang: images use
# /usr/local/go, ours install to /opt/golang).
if [ -z "${GOROOT:-}" ]; then
	if command -v go > /dev/null 2>&1; then
		GOROOT="$(go env GOROOT 2> /dev/null || echo)"
	fi

	if [ -z "${GOROOT:-}" ]; then
		for d in /usr/local/go /opt/golang; do
			if [ -x "$d/bin/go" ]; then
				GOROOT=$d
				break
			fi
		done
		unset d
	fi
fi

cat <<EOT
# Go
[ -z "${GOROOT:-}" ] || path_prepend "${GOROOT}/bin"
export GOPATH="\${GOPATH:-\${WS:-\$HOME/go}}"
path_prepend "\$GOPATH/bin"
export CGO_ENABLED=0
${GO111MODULE:+export GO111MODULE=${GO111MODULE}
}${GOINSECURE:+export GOINSECURE=${GOINSECURE}
}${GOPRIVATE:+export GOPRIVATE=${GOPRIVATE}
}
EOT
