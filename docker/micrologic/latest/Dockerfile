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
RUN apt-get update && apt-get dist-upgrade -y && apt-get install --no-install-recommends -y \
		cairosvg \
		clang-format \
		netcat-openbsd \
		socat \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

# documentation
#
RUN apt-get update && apt-get dist-upgrade -y \
	&& apt-get install -y \
		python3-full \
		python3-venv \
		libclang-dev \
		universal-ctags \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/* \
	&& python3 -m venv /opt/sphinx-env \
	&& /opt/sphinx-env/bin/pip install --no-cache-dir --upgrade \
		pip \
		setuptools \
		wheel \
	&& /opt/sphinx-env/bin/pip install --no-cache-dir \
		"clang~=16.0" \
		"hawkmoth~=0.16.0" \
		"myst-parser~=2.0.0" \
		"sphinx~=7.3.7" \
		"sphinx-rtd-theme~=2.0.0" \
		"sphinx-copybutton~=0.5.2" \
		"sphinx-autobuild~=2021.3.14" \
		"sphinx-markdown-builder~=0.6.0"

ENV PATH="/opt/sphinx-env/bin:$PATH"

# sancus-core
#
ENV SANCUS_VERSION=0.3.10.3
LABEL docker-builder.version.sancus-core=$SANCUS_VERSION

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
