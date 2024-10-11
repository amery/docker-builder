FROM quay.io/amery/docker-ubuntu-vscode-server-nodejs-builder:24.04

ENV GO_VERSION=1.23.2

LABEL docker-builder.version.go="$GO_VERSION"

LABEL docker-builder.run-env.golang="GOPATH GO111MODULE GOINSECURE GOPRIVATE"

#
# update world
#
RUN apt-get update && apt-get dist-upgrade -y && apt-get clean

#
# golang
#
ENV CGO_ENABLED=0

RUN curl -L -o /tmp/go.linux-amd64.tar.gz https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz \
	&& tar -C /opt -zxf /tmp/go.linux-amd64.tar.gz \
	&& rm /tmp/go.linux-amd64.tar.gz \
	&& mv /opt/go /opt/golang \
	&& /opt/golang/bin/go install -v -a ...

COPY golang.sh /etc/entrypoint.d/

ENV PATH=/opt/golang/bin:${PATH}

#
# extra helpers
#
RUN go install -v golang.org/x/tools/cmd/godoc@latest
