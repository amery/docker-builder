FROM quay.io/amery/docker-ubuntu-builder:22.04

ENV GO_VERSION=1.24.6
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
# golang - with architecture detection
#
ENV CGO_ENABLED=0

RUN ARCH=$(dpkg --print-architecture) \
	&& case "$ARCH" in \
		amd64) GO_ARCH="amd64" ;; \
		arm64) GO_ARCH="arm64" ;; \
		armhf) GO_ARCH="armv6l" ;; \
		armel) GO_ARCH="armv6l" ;; \
		i386) GO_ARCH="386" ;; \
		ppc64el) GO_ARCH="ppc64le" ;; \
		s390x) GO_ARCH="s390x" ;; \
		*) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
	esac \
	&& echo "Detected Go version: $GO_VERSION, architecture: $GO_ARCH" \
	&& curl -L -o /tmp/go.linux-${GO_ARCH}.tar.gz https://golang.org/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz \
	&& tar -C /opt -zxf /tmp/go.linux-${GO_ARCH}.tar.gz \
	&& rm /tmp/go.linux-${GO_ARCH}.tar.gz \
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
