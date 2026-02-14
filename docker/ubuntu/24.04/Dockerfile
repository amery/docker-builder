FROM ubuntu:24.04

LABEL docker-builder.version.ubuntu=24.04

# UK mirror
RUN sed -i \
	-e 's|http://archive.ubuntu.com|http://gb.archive.ubuntu.com|' \
	/etc/apt/sources.list.d/ubuntu.sources

# work around apt pipelining issues in buildkit containers
RUN echo 'Acquire::http::Pipeline-Depth "0";' > /etc/apt/apt.conf.d/99no-pipeline

# reduce apt-get install warnings
ENV TERM=xterm

# make sure tzdata is installed without prompts
RUN DEBIAN_FRONTEND="noninteractive" \
	apt-get update && apt-get dist-upgrade -y && apt-get install --no-install-recommends -y \
	tzdata \
	&& apt-get clean

# debconf: delaying package configuration, since apt-utils is not installed
#
RUN apt-get update && apt-get dist-upgrade -y && apt-get install --no-install-recommends -y \
	apt-utils \
	ca-certificates \
	gnupg \
	language-pack-en \
	unminimize \
	&& apt-get clean

# This system has been minimized by removing packages and content that are
# not required on a system that users do not log into.
RUN apt-get update && apt-get dist-upgrade -y \
	&& yes | unminimize \
	&& apt-get clean

# use a locale with utf-8 support
#
ENV LANG=en_GB.UTF-8
RUN update-locale LANG=$LANG LC_MESSAGES=POSIX

# build essentials and basic interactivity
#
RUN apt-get update && apt-get dist-upgrade -y && apt-get install --no-install-recommends -y \
	autoconf \
	autoconf-archive \
	automake \
	bash-completion \
	bison \
	build-essential \
	clang \
	cmake \
	curl \
	flex \
	gawk \
	less \
	libtool-bin \
	man-db \
	pkg-config \
	psmisc \
	python3-pip \
	python3-setuptools \
	time \
	vim \
	&& apt-get clean

# extra development and debugging tools
#
RUN apt-get update && apt-get dist-upgrade -y && apt-get install --no-install-recommends -y \
	cscope \
	gdb \
	git \
	ltrace \
	strace \
	valgrind \
	xxd \
	&& apt-get clean

# dynamic version
#
COPY builder_version.sh /usr/local/bin/builder_version

# trampoline
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
