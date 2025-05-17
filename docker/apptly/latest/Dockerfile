FROM quay.io/amery/docker-ubuntu-vsc-nodejs-golang-builder:24.04

# tools
#
RUN apt-get update && apt-get upgrade -y && apt-get install --no-install-recommends -y \
	protobuf-compiler \
	protoc-gen-go \
	socat \
	&& apt-get clean
