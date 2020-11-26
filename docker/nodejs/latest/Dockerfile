# https://hub.docker.com/_/node/
FROM node:15.1.0-alpine3.12

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
ENV NPM_VERSION="7.0.14"
ENV NCU_VERSION="10.0.0"
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
