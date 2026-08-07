FROM quay.io/amery/docker-apptly-builder:24.04

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
		dos2unix \
		netcat-openbsd \
		socat \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

# documentation. The venv is a layer of its own so re-pinning it does not
# re-run apt.
#
RUN apt-get update && apt-get dist-upgrade -y \
	&& apt-get install -y \
		python3-full \
		python3-dev \
		python3-clang \
		libclang-dev \
		universal-ctags \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

# The clang binding hawkmoth imports comes from apt and the venv inherits
# it. The pip one dlopens a bare libclang.so that no package puts on the
# loader path, so it raises LibclangError at the first header parsed; the
# distro's asks for the versioned soname and matches the libclang built
# beside it.
#
RUN python3 -m venv --system-site-packages /opt/sphinx-env \
	&& /opt/sphinx-env/bin/pip install --no-cache-dir --upgrade \
		pip \
		setuptools \
		wheel \
	&& /opt/sphinx-env/bin/pip install --no-cache-dir \
		"doc8>=1.1.0" \
		"exhale~=0.3.6" \
		"hawkmoth~=0.16.0" \
		"myst-parser~=2.0.0" \
		"rstcheck>=6.2.0" \
		"rstcheck-core>=1.2.0" \
		"sphinx~=7.3.7" \
		"sphinx-rtd-theme~=2.0.0" \
		"sphinx-immaterial~=0.11.0" \
		"sphinx-copybutton~=0.5.2" \
		"sphinx-autobuild~=2021.3.14" \
		"sphinx-markdown-builder~=0.6.0" \
		"vale>=2.30.0" \
	&& echo 'export PATH="/opt/sphinx-env/bin:$PATH"' >> /etc/profile.d/sphinx.sh \
	&& echo 'export VIRTUAL_ENV="/opt/sphinx-env"' >> /etc/profile.d/sphinx.sh

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

# protobuf
#
RUN apt-get update && apt-get upgrade -y && apt-get install --no-install-recommends -y \
	protobuf-compiler \
	protoc-gen-go \
	python3-protobuf \
	python3-grpc-tools \
	&& apt-get clean

# nanopb. The install directory is asked of the interpreter rather than
# spelled out: the venv follows the distro's python, 3.12 on 24.04.
#
# protobuf and protoc come from apt above rather than pip, so the venv
# holds nanopb alone and inherits them. A pip protobuf 5 or later breaks
# 0.4.9.1's extension handling, and nanopb rebuilds its own nanopb_pb2
# against whatever protoc it finds.
#
ENV NANOPB_VERSION=0.4.9.1
ENV NANOPB_VENV=/opt/nanopb-env

RUN python3 -m venv --system-site-packages $NANOPB_VENV \
	&& site_packages="$($NANOPB_VENV/bin/python3 -c \
		'import sysconfig; print(sysconfig.get_paths()["purelib"])')" \
	&& git clone -b $NANOPB_VERSION --depth 1 \
		https://github.com/nanopb/nanopb /usr/src/nanopb \
	&& cd /usr/src/nanopb \
	&& mkdir build \
	&& cd build \
	&& cmake -DCMAKE_INSTALL_PREFIX=/usr \
		-DPython_EXECUTABLE=$NANOPB_VENV/bin/python3 \
		-Dnanopb_PYTHON_INSTDIR_OVERRIDE="$site_packages" \
		../ \
	&& make \
	&& make install \
	&& rm -rf /usr/src/nanopb \
	&& ln -sf $NANOPB_VENV/bin/python3 /usr/local/bin/nanopb-python \
	&& sed -i "1s|^#!/usr/bin/env python3|#!$NANOPB_VENV/bin/python3|" /usr/bin/nanopb_generator* \
	&& echo "export PATH=\"$NANOPB_VENV/bin:\$PATH\"" >> /etc/profile.d/nanopb.sh

# buf
#
ENV BUF_VERSION=latest
RUN env GOBIN=/usr/local/bin \
	go install -v \
		github.com/bufbuild/buf/cmd/...@${BUF_VERSION} \
	&& rm -rf ~/go
