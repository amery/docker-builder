FROM amery/docker-ubuntu-builder:21.04

RUN apt-get update && apt-get install -y --no-install-recommends \
	ccache \
	libncurses5 \
	python \
	unzip \
	zip \
	&& apt-get clean

RUN curl https://storage.googleapis.com/git-repo-downloads/repo > /usr/local/bin/repo \
	&& chmod +x /usr/local/bin/repo

COPY android.sh /etc/entrypoint.d/
