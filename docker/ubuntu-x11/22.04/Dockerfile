FROM quay.io/amery/docker-ubuntu-builder:22.04

LABEL docker-builder.run-env.x11="DISPLAY"

#
# update world
#
RUN apt-get update && apt-get dist-upgrade -y && apt-get clean

#
# X11
#
RUN apt-get update && apt-get install --no-install-recommends -y \
	libgl1 \
	xauth \
	&& apt-get clean

COPY display.sh /etc/entrypoint.d/05-display.sh
