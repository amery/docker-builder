FROM quay.io/amery/docker-ubuntu-vsc-nodejs-golang-builder:24.04

# xtradeb PPA provides real .deb chromium (Ubuntu's is a snap)
RUN apt-get update && apt-get dist-upgrade -y \
	&& apt-get install -y --no-install-recommends \
		software-properties-common \
	&& add-apt-repository -y ppa:xtradeb/apps \
	&& apt-get purge -y \
		software-properties-common \
	&& apt-get clean

# Chromium and headless browser support for MCP browser automation.
#
# Supports two MCP servers:
#
#   @playwright/mcp (Microsoft)
#     - headless with system chromium:
#         npx @playwright/mcp --executable-path /usr/bin/chromium --headless
#       or: PLAYWRIGHT_MCP_EXECUTABLE_PATH=/usr/bin/chromium
#     - headless with bundled chromium (needs `npx playwright install chromium`):
#         npx @playwright/mcp --headless
#     - attached to host browser via CDP:
#         npx @playwright/mcp --cdp-endpoint ws://host:9222
#       (no local browser needed, only Node.js)
#
#   chrome-devtools-mcp (Google Chrome DevTools team)
#     - debugging/performance focused, uses Puppeteer
#     - launch own browser or connect via --browserUrl / --wsEndpoint
#         npx chrome-devtools-mcp
#
RUN apt-get update && apt-get upgrade -y && apt-get install --no-install-recommends -y \
	chromium \
	xvfb \
	fonts-ipafont-gothic \
	fonts-noto-color-emoji \
	fonts-tlwg-loma-otf \
	fonts-unifont \
	fonts-wqy-zenhei \
	xfonts-cyrillic \
	xfonts-scalable \
	&& apt-get clean

# tools
#
RUN apt-get update && apt-get upgrade -y && apt-get install --no-install-recommends -y \
	protobuf-compiler \
	protoc-gen-go \
	socat \
	&& apt-get clean
