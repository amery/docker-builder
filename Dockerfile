# https://hub.docker.com/_/node/
FROM node:9.11.1-alpine

# remove parent's assumptions
#
RUN deluser --remove-home node
CMD [ ]

# update npm
#
RUN npm i -g \
	npm \
	&& rm -rf ~/.npm

# and inject own entrypoint that deals with -e USER_*
#
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
