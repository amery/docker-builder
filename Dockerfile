FROM node:alpine

RUN deluser --remove-home node

RUN npm i -g \
	npm \
	webpack@3 \
	&& rm -rf ~/.npm

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
