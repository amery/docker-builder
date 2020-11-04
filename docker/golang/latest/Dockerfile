# https://hub.docker.com/_/golang/
FROM golang:1.15.3-alpine3.12

# disable CGO and rebuild
ENV CGO_ENABLED=0
RUN go install -tags netgo -v -a all

# install git for `go get`
RUN apk --update add git && \
	rm -rf /var/lib/apt/lists/* && \
	rm /var/cache/apk/*

# graphviz
RUN apk --update add graphviz && \
	rm -rf /var/lib/apt/lists/* && \
	rm /var/cache/apk/*

# and inject entrypoint to deal with -e USER_*
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
