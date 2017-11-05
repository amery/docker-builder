FROM golang:1.9.2-alpine3.6

# disable CGO and rebuild
env CGO_ENABLED=0
RUN go install -a -v net/http 
