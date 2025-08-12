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
		flex \
		gawk \
		libtool-bin \
		pkg-config \
		python-is-python3 \
		python3-pip \
		python3-setuptools \
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
# vscode - secure installation with auto-version and architecture detection
#
RUN VSC_VERSION=$(curl -s https://api.github.com/repos/coder/code-server/releases/latest | jq -r '.tag_name' | sed 's/^v//') \
	&& ARCH=$(dpkg --print-architecture) \
	&& case "$ARCH" in \
		amd64) VSC_ARCH="amd64" ;; \
		arm64) VSC_ARCH="arm64" ;; \
		armhf) VSC_ARCH="armhf" ;; \
		*) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
	esac \
	&& echo "Detected code-server version: $VSC_VERSION, architecture: $VSC_ARCH" \
	&& mkdir -p /tmp/code-server \
	&& cd /tmp/code-server \
	&& curl -fsSL https://github.com/coder/code-server/releases/download/v${VSC_VERSION}/code-server_${VSC_VERSION}_${VSC_ARCH}.deb -o code-server.deb \
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
