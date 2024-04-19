FROM gitpod/workspace-c:latest

USER root

ENV GO_VERSION 1.21.9
ENV NODE_VERSION 18.x

#
# C
#
RUN apt-get update && install-packages \
	autoconf-archive \
	cmake

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

#
# golang
#
ENV CGO_ENABLED 0

RUN curl -L -o /tmp/go.linux-amd64.tar.gz https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz \
	&& tar -C /opt -zxf /tmp/go.linux-amd64.tar.gz \
	&& rm /tmp/go.linux-amd64.tar.gz \
	&& mv /opt/go /opt/golang \
	&& /opt/golang/bin/go install -v -a ...

USER gitpod

ENV PATH /opt/golang/bin:${PATH}
