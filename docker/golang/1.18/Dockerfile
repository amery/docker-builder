# https://hub.docker.com/_/golang/
FROM golang:1.18.10-alpine3.16

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
RUN go install -v golang.org/x/tools/cmd/godoc@v0.18

# dynamic version
#
COPY builder_version.sh /usr/local/bin/builder_version

# runtime environment
#
COPY 10-golang.sh /etc/entrypoint.d/

# and inject entrypoint to deal with -e USER_*
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
