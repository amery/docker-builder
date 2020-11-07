FROM ubuntu:20.04

# UK mirror
RUN sed -i 's|http://archive.ubuntu.com|http://gb.archive.ubuntu.com|' /etc/apt/sources.list

# reduce apt-get install warnings
ENV TERM xterm

# make sure tzdata is installed without prompts
RUN DEBIAN_FRONTEND="noninteractive" \
	apt-get update && apt-get install --no-install-recommends -y \
	tzdata \
	&& apt-get clean

# debconf: delaying package configuration, since apt-utils is not installed
#
RUN apt-get update && apt-get install --no-install-recommends -y \
        apt-utils \
        ca-certificates \
        language-pack-en \
	&& apt-get clean

# use a locale with utf-8 support
#
ENV LANG=en_GB.UTF-8
RUN update-locale LANG=$LANG LC_MESSAGES=POSIX

# build essentials and basic interactivity
#
RUN apt-get update && apt-get install --no-install-recommends -y \
	autoconf \
	autoconf-archive \
	automake \
	bison \
	build-essential \
	clang \
	cmake \
	flex \
	gawk \
	libtool \
	pkg-config \
	psmisc \
	python3-pip \
	python3-setuptools \
	time \
	vim \
	&& apt-get clean

# debugging tools
#
RUN apt-get update && apt-get install --no-install-recommends -y \
	gdb \
	ltrace \
	strace \
	valgrind \
	&& apt-get clean

# trampoline
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
