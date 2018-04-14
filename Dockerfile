# https://hub.docker.com/_/node/
FROM node:9.11.1-alpine

RUN deluser --remove-home node

RUN npm i -g \
	file-loader \
	node-sass \
	npm \
	sass-loader \
	webpack@3 \
	&& rm -rf ~/.npm

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "webpack" ]
