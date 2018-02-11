FROM golang:1.9.4-alpine3.7

# disable CGO and rebuild
ENV CGO_ENABLED=0
RUN go install -tags netgo -v -a all

# install git for `go get`
RUN apk --update add git && \
	rm -rf /var/lib/apt/lists/* && \
	rm /var/cache/apk/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
