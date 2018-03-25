FROM node:alpine

RUN npm i -g npm webpack && \
	rm -rf ~/.npm
