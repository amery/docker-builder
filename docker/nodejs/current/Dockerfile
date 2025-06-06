# https://hub.docker.com/_/node/
FROM node:current-alpine3.20

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
	python3

# update npm and install corepack, yarn and pnpm
#
RUN npm i -g \
		npm@latest \
		corepack@latest \
		yarn@latest \
		pnpm@latest \
	&& rm -rf ~/.npm

# dynamic version
#
COPY builder_version.sh /usr/local/bin/builder_version

# runtime environment
#
COPY node.sh /etc/entrypoint.d/
COPY node-pnpm.sh /etc/entrypoint.d/

# and inject entrypoint to deal with -e USER_*
#
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
