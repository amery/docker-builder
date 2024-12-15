FROM quay.io/amery/docker-ubuntu-builder:22.04

ENV GO_VERSION=1.23.4
ENV NODE_VERSION=20.x

LABEL docker-builder.version.go="$GO_VERSION"
LABEL docker-builder.version.nodejs="$NODE_VERSION"

LABEL docker-builder.run-env.npm="NPM_CONFIG_PREFIX"
LABEL docker-builder.run-env.golang="GOPATH GO111MODULE GOINSECURE GOPRIVATE"

#
# update world
#
RUN apt-get update && apt-get dist-upgrade -y && apt-get clean

#
# node.js
#
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
	&& echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VERSION} nodistro main" \
		> /etc/apt/sources.list.d/nodesource.list \
	&& apt-get update && apt-get install -y \
		nodejs \
	&& apt-get clean

# update npm and install npx, corepack, yarn and pnpm
#
RUN npm i -g \
		npm@latest \
		npx@latest \
		corepack@latest \
		yarn@latest \
		pnpm@latest \
	&& rm -rf ~/.npm

COPY node.sh /etc/entrypoint.d/
COPY node-pnpm.sh /etc/entrypoint.d/

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

#
# dynamic version
#
COPY builder_version.sh /usr/local/bin/builder_version
