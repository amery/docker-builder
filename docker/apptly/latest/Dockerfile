FROM quay.io/amery/docker-ubuntu-vscode-server-nodejs-golang-builder:latest

# tools
#
RUN apt-get update && apt-get upgrade -y && apt-get install --no-install-recommends -y \
	protobuf-compiler \
	protoc-gen-go \
	&& apt-get clean

# interactivity
#
RUN apt-get update && apt-get upgrade -y && apt-get install --no-install-recommends -y \
	bash-completion \
	tig \
	&& apt-get clean
