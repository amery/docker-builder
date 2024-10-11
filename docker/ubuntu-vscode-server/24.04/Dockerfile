FROM quay.io/amery/docker-ubuntu-builder:24.04

#
# update world
#
RUN apt-get update && apt-get dist-upgrade -y && apt-get clean

#
# vscode
#
RUN curl -fsSL https://code-server.dev/install.sh | sh

# code_install_extension() helper for /etc/entrypoint.d
COPY code-extensions.sh /etc/entrypoint.d/code.sh

#
# Vim support
#
RUN apt-get update && apt-get dist-upgrade -y && apt-get install -y \
	&& apt-get update && apt-get install -y \
		neovim \
	&& apt-get clean

COPY code-vim.sh /etc/entrypoint.d/

#
# dynamic version
#
COPY builder_version.sh /usr/local/bin/builder_version
