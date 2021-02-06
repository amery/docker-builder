# https://hub.docker.com/_/golang/
FROM golang:1.15.8-alpine3.13

LABEL docker-builder.version.alpine=3.13
LABEL docker-builder.version.golang=1.15.8

LABEL docker-builder.run-env.golang=GOPATH

# disable CGO and rebuild
ENV CGO_ENABLED=0
RUN go install -tags netgo -v -a all

RUN apk --update --no-cache add \
	git \
	graphviz \
	make

# and inject entrypoint to deal with -e USER_*
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
