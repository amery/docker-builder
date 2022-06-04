FROM amery/docker-ubuntu-builder:22.04

ENV GO_VERSION 1.18.2
ENV GODOC_VERSION 0.1.10
ENV NODE_VERSION 16.x
ENV NPM_VERSION 8.9.0

LABEL docker-builder.version.go="$GO_VERSION"
LABEL docker-builder.version.godoc="$GODOC_VERSION"
LABEL docker-builder.version.nodejs="$NODE_VERSION"
LABEL docker-builder.version.npm="$NPM_VERSION"

LABEL docker-builder.run-env.npm="NPM_CONFIG_PREFIX"
LABEL docker-builder.run-env.golang="GOPATH GO111MODULE GOINSECURE GOPRIVATE"

#
# update world
#
RUN apt-get update && apt-get dist-upgrade -y && apt-get clean

#
# node.js
#
WORKDIR /tmp
RUN apt-get update \
	&& curl -sL https://deb.nodesource.com/setup_${NODE_VERSION} | bash - \
	&& apt-get update && apt-get install -y \
		nodejs \
	&& apt-get clean

RUN npm update && npm i -g \
		npm@${NPM_VERSION} \
		npm-check-updates@${NCU_VERSION} \
		npx \
		yarn \
	&& rm -rf ~/.npm

COPY npm.sh /etc/entrypoint.d/

#
# golang
#
ENV CGO_ENABLED 0

RUN curl -L -o /tmp/go.linux-amd64.tar.gz https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz \
	&& tar -C /opt -zxf /tmp/go.linux-amd64.tar.gz \
	&& rm /tmp/go.linux-amd64.tar.gz \
	&& mv /opt/go /opt/golang \
	&& /opt/golang/bin/go install -v -a ...

COPY golang.sh /etc/entrypoint.d/

ENV PATH /opt/golang/bin:${PATH}

#
# extra helpers
#
RUN go install -v golang.org/x/tools/cmd/godoc@v${GODOC_VERSION}

#
# dynamic version
#
COPY builder_version.sh /usr/local/bin/builder_version