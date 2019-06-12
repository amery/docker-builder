FROM golang:1.12.1-alpine3.9

# disable CGO and rebuild
ENV CGO_ENABLED=0
RUN go install -tags netgo -v -a all

# install git for `go get`
RUN apk --update add git && \
	rm -rf /var/lib/apt/lists/* && \
	rm /var/cache/apk/*

RUN apk --update add graphviz && \
	rm -rf /var/lib/apt/lists/* && \
	rm /var/cache/apk/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
