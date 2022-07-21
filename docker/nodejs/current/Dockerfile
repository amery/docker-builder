# https://hub.docker.com/_/node/
FROM node:current-alpine3.15

LABEL docker-builder.run-env.npm="NPM_CONFIG_PREFIX"

# remove parent's assumptions
#
RUN deluser --remove-home node
CMD [ ]

# dependencies
RUN apk --update --no-cache add \
	g++ \
	git \
	make \
	openssh \
	python2

# update npm and install npx
#
RUN npm i -g \
		npm@latest \
		npx@latest \
	&& rm -rf ~/.npm

# yarn
#
RUN apk --update --no-cache add \
	yarn

# dynamic version
#
COPY builder_version.sh /usr/local/bin/builder_version

# runtime environment
#
COPY node.sh /etc/entrypoint.d/

# and inject entrypoint to deal with -e USER_*
#
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
