
WS     ?= $(CURDIR)
GOPATH ?= $(WS)
GOBIN  ?= $(GOPATH)/bin

DOCKER_RUN ?= $(WS)/docker.sh

GO    = $(DOCKER_RUN) go
GOGET = $(GO) get -v

# godoc
#
.PHONY: godoc
godoc: PORT=6060
godoc: $(GOBIN)/godoc
	DOCKER_EXPOSE=$(PORT) $(DOCKER_RUN) godoc -http=:$(PORT)

$(GOBIN)/godoc: FORCE
	$(GOGET) golang.org/x/tools/cmd/godoc

.PHONY: clean
clean:
	@rm -rf $(WS)/bin $(WS)/pkg

.PHONY: FORCE
FORCE:
