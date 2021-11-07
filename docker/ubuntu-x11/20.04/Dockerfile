FROM amery/docker-ubuntu-builder:20.04

LABEL docker-builder.run-env.x11="DISPLAY"

RUN apt-get update && apt-get dist-upgrade -y && apt-get install -y \
	libgl1 \
	xauth

COPY display.sh /etc/entrypoint.d/
