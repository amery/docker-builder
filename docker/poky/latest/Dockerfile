FROM amery/docker-ubuntu-builder:18.04

# OE dependencies
RUN apt-get update && apt-get install --no-install-recommends -y \
	chrpath cpio diffstat git python texinfo wget \
	&& apt-get clean

COPY entrypoint.sh /etc/entrypoint.d/20-poky.sh
