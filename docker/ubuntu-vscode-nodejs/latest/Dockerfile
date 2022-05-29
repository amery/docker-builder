FROM amery/docker-ubuntu-vscode-builder:latest

ENV NODE_VERSION="16.x"
ENV NPM_VERSION="8.11.0"

LABEL docker-builder.version.nodejs="$NODE_VERSION"
LABEL docker-builder.version.npm="$NPM_VERSION"

LABEL docker-builder.run-env.npm="NPM_CONFIG_PREFIX"

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
# dynamic version
#
COPY builder_version.sh /usr/local/bin/builder_version
