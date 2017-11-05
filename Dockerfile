FROM golang:1.9.2-alpine3.6

# disable CGO and rebuild
ENV CGO_ENABLED=0
RUN go install -tags netgo -v -a all

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
