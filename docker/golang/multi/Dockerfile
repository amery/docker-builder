FROM quay.io/amery/docker-golang-builder:1.22

RUN GO_VERSION=$(go version | sed -e 's|.* go\([1-9][^ ]\+\) .*|\1|') \
	; ln -s ../go/bin/go /usr/local/bin/go-${GO_VERSION} \
	; ln -s ../go/bin/go /usr/local/bin/go-${GO_VERSION%.*} \
	;

RUN apk --update --no-cache --virtual /tmp/.build-deps add \
		bash \
		curl \
		gcc \
		musl-dev \
	&& for GO_VERSION in \
			"1.18.10" \
			"1.19.13" \
			"1.20.14" \
			"1.21.12" \
			; do \
		curl -Ls -o /tmp/go.tgz https://golang.org/dl/go${GO_VERSION}.src.tar.gz \
		&& tar -C /tmp -zxf /tmp/go.tgz \
		&& mv /tmp/go /usr/local/go${GO_VERSION} \
		&& cd /usr/local/go${GO_VERSION}/src \
		&& echo "Building Go ${GO_VERSION}" \
		&& env \
			GOCACHE='/tmp/gocache' \
			GOROOT_BOOTSTRAP=$(go env GOROOT) \
			GOROOT_FINAL=${PWD%/*} \
			./make.bash \
		&& ln -s ../go${GO_VERSION}/bin/go /usr/local/bin/go-${GO_VERSION} \
		&& ln -s ../go${GO_VERSION}/bin/go /usr/local/bin/go-${GO_VERSION%.*} \
		&& rm -rf \
			/tmp/go \
			/tmp/go.tar.gz \
			/tmp/gocache \
			../pkg/*/cmd \
			../pkg/bootstrap \
			../pkg/obj \
			../pkg/tool/*/api \
			../pkg/tool/*/go_bootstrap \
			../src/cmd/dist/dist \
		&& go-${GO_VERSION} version \
		&& go-${GO_VERSION} env GOROOT \
		; \
	done \
	&& apk del --no-network /tmp/.build-deps

COPY builder_version.sh /usr/local/bin/builder_version
