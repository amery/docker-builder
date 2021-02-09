# https://hub.docker.com/_/node/
FROM node:current-alpine3.12

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
	&& npm i -g npm \
	&& npm i -g npm-check-updates \
	&& rm -rf ~/.npm

# dynamic version
#
COPY builder_version.sh /usr/local/bin/builder_version

# runtime environment
#
COPY npm.sh /etc/entrypoint.d/

# and inject entrypoint to deal with -e USER_*
#
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
