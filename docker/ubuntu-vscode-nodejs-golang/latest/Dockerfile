FROM amery/docker-ubuntu-vscode-nodejs-builder:latest

ENV GO_VERSION 1.17.3
ENV GODOC_VERSION 0.1.7

LABEL docker-builder.version.go="$GO_VERSION"
LABEL docker-builder.version.godoc="$GODOC_VERSION"

LABEL docker-builder.run-env.golang="GOPATH GO111MODULE GOINSECURE GOPRIVATE"

#
# golang
#
ENV CGO_ENABLED 0

RUN curl -L -o /tmp/go.linux-amd64.tar.gz https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz \
	&& tar -C /opt -zxf /tmp/go.linux-amd64.tar.gz \
	&& rm /tmp/go.linux-amd64.tar.gz \
	&& mv /opt/go /opt/golang \
	&& /opt/golang/bin/go install -v -a ...

ENV PATH /opt/golang/bin:${PATH}

#
# extra helpers
#
RUN go install -v golang.org/x/tools/cmd/godoc@v${GODOC_VERSION}
