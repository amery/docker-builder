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

COPY 30-poky.sh /etc/entrypoint.d/30-poky.sh

# Embed run-hook.sh template for workspace deployment
ARG RUN_HOOK_SHA256
COPY run-hook.sh /usr/local/share/docker-builder/run-hook.sh
LABEL docker-builder.run-hook.sha256="${RUN_HOOK_SHA256}"
