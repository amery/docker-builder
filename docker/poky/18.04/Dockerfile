FROM quay.io/amery/docker-ubuntu-builder:18.04

# Point to run-hook.sh URL for documentation (not yet used by docker-builder-run)
LABEL docker-builder.run-hook="https://raw.githubusercontent.com/amery/docker-builder/master/docker/poky/18.04/run-hook.sh"

# Tell docker-builder-run which OE env vars to pass through
LABEL docker-builder.run-env.oe="MACHINE DISTRO TCLIBC OEROOT DL_DIR BUILDDIR BB_ENV_EXTRAWHITE"

#
# update world
#
RUN apt-get update \
	&& DEBIAN_FRONTEND="noninteractive" apt-get dist-upgrade -y \
	&& apt-get clean

# OE/Yocto dependencies for pyro (2.3) era
RUN apt-get update && apt-get dist-upgrade -y && apt-get install --no-install-recommends -y \
	chrpath \
	cpio \
	diffstat \
	python \
	texinfo \
	&& apt-get clean

# Drop the base image's python venv plugin. It prepends a venv whose
# bin/python is python3 — a useful `python` on the bases, which have none,
# but here it shadows the python2 installed above. Pyro predates python3 as
# `python`: pycairo's bundled waf 1.6.4 defines its Node class inside a
# function and cannot pickle its build cache under python3.5+.
RUN rm -f /etc/entrypoint.d/10-python.sh

COPY 30-poky.sh /etc/entrypoint.d/30-poky.sh

# Embed run-hook.sh template for workspace deployment
ARG RUN_HOOK_SHA256
COPY run-hook.sh /usr/local/share/docker-builder/run-hook.sh
LABEL docker-builder.run-hook.sha256="${RUN_HOOK_SHA256}"
