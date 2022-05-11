# https://hub.docker.com/_/node/
FROM node:lts-alpine3.15

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

# update npm and install ncu
#
# workaround `EXDEV: cross-device link not permitted` bug
#
RUN mv /usr/local/lib/node_modules /usr/local/lib/node_modules.tmp \
	&& mv /usr/local/lib/node_modules.tmp /usr/local/lib/node_modules \
	&& npm i -g \
		npm \
		npm-check-updates \
		npx \
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
COPY npm.sh /etc/entrypoint.d/

# and inject entrypoint to deal with -e USER_*
#
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
