FROM quay.io/amery/docker-ubuntu-vsc-nodejs-builder:24.04

ENV GO_VERSION=1.24.3

#
# update world
#
RUN apt-get update && apt-get dist-upgrade -y && apt-get clean

#
# golang - with architecture detection
#
ENV CGO_ENABLED=0

RUN ARCH=$(dpkg --print-architecture) \
	&& case "$ARCH" in \
		amd64) GO_ARCH="amd64" ;; \
		arm64) GO_ARCH="arm64" ;; \
		armhf) GO_ARCH="armv6l" ;; \
		armel) GO_ARCH="armv6l" ;; \
		i386) GO_ARCH="386" ;; \
		ppc64el) GO_ARCH="ppc64le" ;; \
		s390x) GO_ARCH="s390x" ;; \
		*) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
	esac \
	&& echo "Detected Go version: $GO_VERSION, architecture: $GO_ARCH" \
	&& curl -L -o /tmp/go.linux-${GO_ARCH}.tar.gz https://golang.org/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz \
	&& tar -C /opt -zxf /tmp/go.linux-${GO_ARCH}.tar.gz \
	&& rm /tmp/go.linux-${GO_ARCH}.tar.gz \
	&& mv /opt/go /opt/golang \
	&& /opt/golang/bin/go install -v -a ...

ENV PATH=/opt/golang/bin:${PATH}
