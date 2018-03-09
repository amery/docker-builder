
WS     ?= $(CURDIR)
GOPATH ?= $(WS)
GOBIN  ?= $(GOPATH)/bin

DOCKER_RUN ?= $(WS)/docker.sh

GO    = $(DOCKER_RUN) go
GOGET = $(GO) get -v

# go fmt
#
.PHONY: gofmt
gofmt:
	@echo $(filter %.go, $^) | xargs -r $(DOCKER_RUN) gofmt -l -w

# go generate
#
.PHONY: gogenerate
gogenerate:
	@echo $(filter %.go, $^) | xargs -r grep -l '^//go:generate' | sed -e 's|/[^/]\+$$||g' | sort -u | \
		while read d; do \
			grep -l '^//go:generate' $$d/*.go | xargs -r $(GO) generate -v -x; \
		done

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
