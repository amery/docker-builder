FROM node:alpine

RUN npm i -g \
	npm \
	webpack@3 \
	&& rm -rf ~/.npm
