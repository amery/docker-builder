FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

#
# foundation
#
RUN apt-get update \
	&& apt-get dist-upgrade -y \
	&& apt-get install --no-install-recommends -y \
		ca-certificates \
		language-pack-en \
		unminimize \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

# This system has been minimized by removing packages and content that are
# not required on a system that users do not log into.
RUN yes | unminimize

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
		curl \
		flex \
		gawk \
		gnupg \
		jq \
		libtool-bin \
		pkg-config \
		python3-pip \
		python3-setuptools \
		time \
		vim \
		wget \
	&& apt-get clean

#
# extra development tools and interactivity
#
RUN apt-get update && apt-get dist-upgrade -y \
	&& apt-get install --no-install-recommends -y \
		tig \
	&& apt-get clean

#
# vscode - secure installation with auto-version detection
#
RUN VSC_VERSION=$(curl -s https://api.github.com/repos/coder/code-server/releases/latest | jq -r '.tag_name' | sed 's/^v//') \
	&& echo "Detected code-server version: $VSC_VERSION" \
	&& mkdir -p /tmp/code-server \
	&& cd /tmp/code-server \
	&& curl -fsSL https://github.com/coder/code-server/releases/download/v${VSC_VERSION}/code-server_${VSC_VERSION}_amd64.deb -o code-server.deb \
	&& dpkg -i code-server.deb \
	&& rm -rf /tmp/code-server \
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
COPY entrypoint.sh /entrypoint.sh
COPY devcontainer.sh /devcontainer-init.sh

RUN chmod +x /usr/local/bin/builder_version \
	/entrypoint.sh \
	/devcontainer-init.sh

ENTRYPOINT ["/entrypoint.sh"]
