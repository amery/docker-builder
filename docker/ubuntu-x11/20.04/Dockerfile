FROM amery/docker-ubuntu-builder:20.04

LABEL docker-builder.run-env.x11="DISPLAY"

RUN apt-get update && apt-get install -y \
	xauth

COPY display.sh /etc/entrypoint.d/
