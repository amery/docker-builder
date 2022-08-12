FROM amery/docker-ubuntu-x11-builder:20.04

#
# vscode
#
RUN apt-get update && apt-get dist-upgrade -y && apt-get install -y --no-install-recommends \
		gnupg \
		libasound2 \
		libgbm1 \
		libgtk-3-0 \
		libnss3 \
		libsecret-1-0 \
		libx11-xcb1 \
		libxkbfile1 \
		libxshmfence1 \
		libxss1 \
		xdg-utils \
	&& curl -L -o /tmp/vscode.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" \
	&& dpkg -i /tmp/vscode.deb \
	&& rm /tmp/vscode.deb \
	&& apt-get clean

# code_install_extension() helper for /etc/entrypoint.d
COPY code-extensions.sh /etc/entrypoint.d/code.sh

#
# Vim support
#
RUN apt-get update && apt-get dist-upgrade -y && apt-get install -y \
	software-properties-common \
	&& add-apt-repository ppa:neovim-ppa/stable \
	&& apt-get update && apt-get install -y \
		neovim \
	&& apt-get clean

COPY code-vim.sh /etc/entrypoint.d/

#
# dynamic version
#
COPY builder_version.sh /usr/local/bin/builder_version
