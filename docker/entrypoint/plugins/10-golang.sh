# shellcheck shell=sh

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

# Bake the entrypoint-time default: the login `su -` strips GOPATH and
# WS, so only the value captured here survives into the login shell; the
# user's GOPATH takes precedence over the workspace. When neither is set
# — the devcontainer build, where they arrive only in the login
# environment — defer resolution to login time instead, matching
# gen_profile's baked+deferred workspace pair.
if [ -n "${GOPATH:-}${WS:-}" ]; then
	GOPATH_DEFAULT="${GOPATH:-$WS}"
else
	# literal on purpose: emitted into the profile, expanded at login
	# shellcheck disable=SC2016
	GOPATH_DEFAULT='${WS:-$HOME/go}'
fi

cat <<EOT
# Go
[ -z "${GOROOT:-}" ] || path_prepend "${GOROOT}/bin"
export GOPATH="\${GOPATH:-$GOPATH_DEFAULT}"
export GOBIN="\$GOPATH/bin"
path_prepend "\$GOBIN"
export CGO_ENABLED=0
${GO111MODULE:+export GO111MODULE=${GO111MODULE}
}${GOINSECURE:+export GOINSECURE=${GOINSECURE}
}${GOPRIVATE:+export GOPRIVATE=${GOPRIVATE}
}
EOT
unset GOPATH_DEFAULT
