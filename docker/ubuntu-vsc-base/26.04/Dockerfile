# Microsoft dropped the hyphen in the 26.04 tag: it is "ubuntu26.04",
# not "ubuntu-26.04" the way 24.04 uses "ubuntu-24.04".
FROM mcr.microsoft.com/devcontainers/base:ubuntu26.04

#
# foundation
#
RUN apt-get update && apt-get dist-upgrade -y \
	&& apt-get install --no-install-recommends -y \
		ca-certificates \
		language-pack-en \
		unminimize \
	&& apt-get clean

# This system has been minimized by removing packages and content that are
# not required on a system that users do not log into.
RUN apt-get update && apt-get dist-upgrade -y \
	&& yes | unminimize \
	&& apt-get clean

ENV LANG=en_GB.UTF-8
RUN update-locale LANG=$LANG LC_MESSAGES=POSIX

#
# build essentials and basic interactivity
#
RUN apt-get update && apt-get dist-upgrade -y \
	&& apt-get install --no-install-recommends -y \
		autoconf \
		autoconf-archive \
		automake \
		bison \
		clang \
		cmake \
		flex \
		gawk \
		libtool-bin \
		pkg-config \
		python-is-python3 \
		python3-pip \
		python3-setuptools \
		python3-venv \
		time \
		vim \
	&& apt-get clean

#
# debugging
#
RUN apt-get update && apt-get dist-upgrade -y \
	&& apt-get install --no-install-recommends -y \
		gdb \
		gdbserver \
		valgrind \
		ltrace \
		netcat-openbsd \
	&& apt-get clean

#
# extra development tools and interactivity
#
RUN apt-get update && apt-get dist-upgrade -y \
	&& apt-get install --no-install-recommends -y \
		ripgrep \
		tig \
		tmux \
		xxd \
	&& apt-get clean

#
# github cli
#
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
	&& chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& apt-get update \
	&& apt-get install --no-install-recommends -y gh \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

#
# devcontainer
#

LABEL devcontainer.metadata='[\
{ "id": "ghcr.io/devcontainers/features/common-utils:2" }, \
{ "id": "ghcr.io/devcontainers/features/git:1" } \
]'

#
# dynamic version
#
COPY builder_version.sh /usr/local/bin/builder_version

#
# entrypoint
#
COPY 05-gnupg.sh /etc/entrypoint.d/
COPY 10-python.sh /etc/entrypoint.d/
COPY shared.sh /usr/local/lib/docker-builder/entrypoint.sh
COPY entrypoint.sh /entrypoint.sh
COPY devcontainer.sh /devcontainer-init.sh

RUN chmod +x /usr/local/bin/builder_version \
	/entrypoint.sh \
	/devcontainer-init.sh

ENTRYPOINT ["/entrypoint.sh"]
