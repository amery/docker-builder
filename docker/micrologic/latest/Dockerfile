FROM quay.io/amery/docker-ubuntu-vsc-nodejs-golang-builder:24.04

# extra dependencies
RUN apt-get update && apt-get upgrade -y && apt-get install --no-install-recommends -y \
	libmpack-dev \
	libmxml-dev \
	libncurses-dev \
	libtokyocabinet-dev \
	&& apt-get clean

# testing and interactivity
#
RUN apt-get update && apt-get upgrade -y && apt-get install --no-install-recommends -y \
	cairosvg \
	clang-format \
	netcat-openbsd \
	socat \
	&& apt-get clean

# sancus-core
#
ENV SANCUS_VERSION=0.3.10.3
LABEL docker-builder.version.sancus-core $SANCUS_VERSION

RUN git clone -b $SANCUS_VERSION --depth 1 \
		https://github.com/sancus-project/sancus-core /usr/src/sancus-core \
	&& cd /usr/src/sancus-core \
	&& autoreconf -ivf \
	&& mkdir build \
	&& cd build \
	&& ../configure \
	&& make \
	&& make install \
	&& rm -rf /usr/src/sancus-core

# libbacktrace
#
RUN git clone --depth 1 \
		https://github.com/ianlancetaylor/libbacktrace /usr/src/libbacktrace \
	&& cd /usr/src/libbacktrace \
	&& autoreconf -ivf \
	&& mkdir build \
	&& cd build \
	&& ../configure \
	&& make \
	&& make install \
	&& rm -rf /usr/src/libbacktrace

# protobuf
#
RUN apt-get update && apt-get upgrade -y && apt-get install --no-install-recommends -y \
	protobuf-compiler \
	protoc-gen-go \
	python3-protobuf \
	python3-grpc-tools \
	&& apt-get clean

# nanopb
#
RUN git clone --depth 1 \
		https://github.com/nanopb/nanopb /usr/src/nanopb \
	&& cd /usr/src/nanopb \
	&& mkdir build \
	&& cd build \
	&& cmake -DCMAKE_INSTALL_PREFIX=/usr ../ \
	&& make \
	&& make install \
	&& rm -rf /usr/src/nanopb

# buf
#
ENV BUF_VERSION=latest
RUN env GOBIN=/usr/local/bin \
	&& go install -v \
		github.com/bufbuild/buf/cmd/buf@${BUF_VERSION} \
	&& rm -rf ~/go
