FROM quay.io/amery/docker-ubuntu-builder:18.04

# Point to run-hook.sh URL for documentation (not yet used by docker-builder-run)
LABEL docker-builder.run-hook="https://raw.githubusercontent.com/amery/docker-builder/master/docker/poky/18.04/run-hook.sh"

# Tell docker-builder-run which OE env vars to pass through
LABEL docker-builder.run-env.oe="MACHINE DISTRO TCLIBC OEROOT DL_DIR BUILDDIR BB_ENV_EXTRAWHITE"

#
# update world
#
RUN apt-get update && apt-get dist-upgrade -y && apt-get clean

# OE/Yocto dependencies for pyro (2.3) era
RUN apt-get update && apt-get dist-upgrade -y && apt-get install --no-install-recommends -y \
	chrpath \
	cpio \
	diffstat \
	python \
	texinfo \
	&& apt-get clean

COPY entrypoint.sh /etc/entrypoint.d/20-poky.sh
