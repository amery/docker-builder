FROM quay.io/amery/docker-ubuntu-vsc-base-builder:24.04

ENV NODE_VERSION="22.x"

#
# update world
#
RUN apt-get update && apt-get dist-upgrade -y && apt-get clean

#
# node.js
#
RUN apt-get update \
	&& curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
	&& echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VERSION} nodistro main" \
		> /etc/apt/sources.list.d/nodesource.list \
	&& apt-get update && apt-get install -y \
		nodejs \
	&& apt-get clean

# update npm and install corepack, yarn and pnpm
#
RUN npm i -g \
	npm@latest \
	corepack@latest \
	yarn@latest \
	pnpm@latest \
	&& rm -rf ~/.npm
