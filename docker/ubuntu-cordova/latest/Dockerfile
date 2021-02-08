FROM amery/docker-ubuntu-android-builder:latest

ENV NODE_VERSION="15.x"
ENV NPM_VERSION="7.5.2"
ENV NCU_VERSION="11.1.1"

LABEL docker-builder.version.nodejs="$NODE_VERSION"
LABEL docker-builder.version.npm="$NPM_VERSION"
LABEL docker-builder.version.ncu="$NCU_VERSION"

LABEL docker-builder.run-env.npm="NPM_CONFIG_PREFIX"

#
# node.js
#

# WORKDIR needed for installing node 15.x+
WORKDIR /tmp
RUN apt-get update \
	&& curl -sL https://deb.nodesource.com/setup_${NODE_VERSION} | bash - \
	&& apt-get update && apt-get install -y \
		nodejs \
	&& apt-get clean

RUN npm update && npm i -g \
		npm@${NPM_VERSION} \
		npm-check-updates@${NCU_VERSION} \
	&& rm -rf ~/.npm

#
# cordova
#
RUN npm update && npm i -g \
		cordova \
		cordova-android \
		cordova-browser \
	&& rm -rf ~/.npm

COPY builder_version.sh /usr/local/bin/builder_version
