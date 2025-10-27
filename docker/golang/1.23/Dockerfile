# https://hub.docker.com/_/golang/
FROM golang:1.23.12-alpine3.22

LABEL docker-builder.run-env.golang="GOPATH GO111MODULE GOINSECURE GOPRIVATE"

# disable CGO and rebuild
ENV CGO_ENABLED=0
RUN go install -v -a ...

RUN apk --update --no-cache add \
	bash \
	git \
	graphviz \
	make \
	su-exec

# extra helpers
ENV GODOC_VERSION=v0.36
RUN go install -v golang.org/x/tools/cmd/godoc@${GODOC_VERSION}

# dynamic version
#
COPY builder_version.sh /usr/local/bin/builder_version

# runtime environment
#
COPY 10-golang.sh /etc/entrypoint.d/

# and inject entrypoint to deal with -e USER_*
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
