FROM golang:1.9.2-alpine3.6

# disable CGO and rebuild
ENV CGO_ENABLED=0
RUN go install -a -v net/http 

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
