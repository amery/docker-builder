FROM quay.io/amery/docker-ubuntu-builder:22.04

#
# update world
#
RUN apt-get update && apt-get dist-upgrade -y && apt-get clean

#
# android dependencies
#
RUN apt-get update && apt-get install -y --no-install-recommends \
	ccache \
	libncurses5 \
	python2 \
	python3 \
	unzip \
	zip \
	&& apt-get clean

RUN curl https://storage.googleapis.com/git-repo-downloads/repo > /usr/local/bin/repo \
	&& chmod +x /usr/local/bin/repo

COPY android.sh /etc/entrypoint.d/
