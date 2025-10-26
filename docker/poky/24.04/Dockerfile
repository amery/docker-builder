FROM quay.io/amery/docker-ubuntu-builder:24.04

# Point to run-hook.sh URL for documentation (not yet used by docker-builder-run)
LABEL docker-builder.run-hook="https://raw.githubusercontent.com/amery/docker-builder/master/docker/poky/24.04/run-hook.sh"

# Tell docker-builder-run which OE env vars to pass through
LABEL docker-builder.run-env.oe="MACHINE DISTRO TCLIBC OEROOT DL_DIR BUILDDIR BB_ENV_PASSTHROUGH_ADDITIONS"

# Update world
RUN apt-get update && apt-get dist-upgrade -y && apt-get clean

# OE/Yocto core dependencies
RUN apt-get update && apt-get dist-upgrade -y && apt-get install --no-install-recommends -y \
	chrpath \
	cpio \
	diffstat \
	texinfo \
	wget \
	&& apt-get clean

# Version control systems
RUN apt-get update && apt-get dist-upgrade -y && apt-get install --no-install-recommends -y \
	git-lfs \
	subversion \
	&& apt-get clean

# Python dependencies for OE/Yocto
RUN apt-get update && apt-get dist-upgrade -y && apt-get install --no-install-recommends -y \
	python3-git \
	python3-jinja2 \
	python3-pexpect \
	&& apt-get clean

# Architecture support for 32-bit builds
RUN apt-get update && apt-get dist-upgrade -y && apt-get install --no-install-recommends -y \
	gcc-multilib \
	g++-multilib \
	&& apt-get clean

# Compression tools
RUN apt-get update && apt-get dist-upgrade -y && apt-get install --no-install-recommends -y \
	zstd \
	lz4 \
	&& apt-get clean

# OE-specific entrypoint extension
COPY entrypoint.sh /etc/entrypoint.d/20-poky.sh
