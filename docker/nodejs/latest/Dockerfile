# https://hub.docker.com/_/node/
FROM node:15.0.1-alpine3.12

# remove parent's assumptions
#
RUN deluser --remove-home node
CMD [ ]

# git
RUN apk --update add \
	git \
	openssh \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm /var/cache/apk/*

# update npm
#
# workaround `EXDEV: cross-device link not permitted` bug
#
RUN mv /usr/local/lib/node_modules /usr/local/lib/node_modules.tmp \
	&& mv /usr/local/lib/node_modules.tmp /usr/local/lib/node_modules \
	&& npm i -g npm@latest \
	&& rm -rf ~/.npm

# and inject entrypoint to deal with -e USER_*
#
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
