# https://hub.docker.com/_/node/
FROM node:15.4.0-alpine3.12

ENV NPM_VERSION="7.5.1"
ENV NCU_VERSION="11.1.1"

LABEL docker-builder.version.alpine=3.12
LABEL docker-builder.version.nodejs=15.4.0
LABEL docker-builder.version.npm="$NPM_VERSION"
LABEL docker-builder.version.ncu="$NCU_VERSION"

LABEL docker-builder.run-env.npm="NPM_CONFIG_PREFIX"

# remove parent's assumptions
#
RUN deluser --remove-home node
CMD [ ]

# dependencies
RUN apk --update add \
	git \
	openssh \
	g++ make python2 \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm /var/cache/apk/*

# update npm and install ncu
#
# workaround `EXDEV: cross-device link not permitted` bug
#
RUN mv /usr/local/lib/node_modules /usr/local/lib/node_modules.tmp \
	&& mv /usr/local/lib/node_modules.tmp /usr/local/lib/node_modules \
	&& npm i -g npm@${NPM_VERSION} \
	&& npm i -g npm-check-updates@${NCU_VERSION} \
	&& rm -rf ~/.npm

# and inject entrypoint to deal with -e USER_*
#
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
