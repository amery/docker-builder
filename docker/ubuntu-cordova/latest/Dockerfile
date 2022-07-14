FROM amery/docker-ubuntu-android-builder:latest

ENV NODE_VERSION="16.x"

LABEL docker-builder.version.nodejs="$NODE_VERSION"

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
		npm@latest \
		npx@latest \
		yarn@latest \
	&& rm -rf ~/.npm

COPY node.sh /etc/entrypoint.d/

#
# cordova
#
RUN npm update && npm i -g \
		cordova \
		cordova-android \
		cordova-browser \
	&& rm -rf ~/.npm

COPY builder_version.sh /usr/local/bin/builder_version
