FROM amery/docker-ubuntu-x11-builder:latest

RUN apt-get update && apt-get install -y --no-install-recommends \
		gnupg \
		libgbm1 \
		libgtk-3-0 \
		libnss3 \
		libsecret-1-0 \
		libx11-xcb1 \
		libxkbfile1 \
		libxss1 \
		wget \
	&& wget -O /tmp/vscode.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" \
	&& dpkg -i /tmp/vscode.deb \
	&& rm /tmp/vscode.deb \
	&& apt-get remove -y \
		wget \
	&& apt-get clean

COPY builder_version.sh /usr/local/bin/builder_version
