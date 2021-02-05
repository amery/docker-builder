# https://hub.docker.com/_/golang/
FROM golang:1.15.6-alpine3.12

LABEL docker-builder.version.alpine=3.12
LABEL docker-builder.version.golang=1.15.6

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
