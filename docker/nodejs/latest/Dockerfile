# https://hub.docker.com/_/node/
FROM node:12.1.0-alpine

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
RUN npm i -g \
	npm@latest \
	&& rm -rf ~/.npm

# and inject own entrypoint that deals with -e USER_*
#
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
