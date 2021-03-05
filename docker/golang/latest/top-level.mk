
WS     ?= $(CURDIR)
GOPATH ?= $(WS)
GOBIN  ?= $(GOPATH)/bin

DOCKER = $(shell which docker)
ifneq ($(DOCKER),)
DOCKER_RUN ?= $(WS)/run.sh
else
DOCKER_RUN ?=
endif

GOFMT_ARGS ?= -l -w
GOGET_ARGS ?= -v
GOTEST_ARGS ?= -v
GOGENERATE_ARGS ?= -v -x

GO    = $(DOCKER_RUN) go
GOFMT = $(DOCKER_RUN) gofmt
GODOC = $(DOCKER_RUN) godoc

GOGET = $(GO) get $(GOGET_ARGS)
GOTEST = $(GO) test $(GOTEST_ARGS)
GOGENERATE = $(GO) generate $(GOGENERATE_ARGS)

# go fmt
#
.PHONY: gofmt
gofmt:
	@echo $(filter %.go, $^) | xargs -r $(GOFMT) $(GOFMT_ARGS)

# go generate
#
.PHONY: gogenerate
gogenerate:
	@echo $(filter %.go, $^) | xargs -r grep -l '^//go:generate' | sed -e 's|/[^/]\+$$||g' | sort -u | \
		while read d; do \
			grep -l '^//go:generate' $$d/*.go | xargs -r $(GOGENERATE); \
		done

# godoc
#
.PHONY: godoc
godoc: PORT=6060
godoc: $(GOBIN)/godoc
	DOCKER_EXPOSE=$(PORT) $(GODOC) -http=:$(PORT)

$(GOBIN)/godoc: FORCE
	$(GOGET) golang.org/x/tools/cmd/godoc

.PHONY: clean
clean:
	@$(GO) clean -modcache
	@rm -rf $(WS)/bin $(WS)/pkg

.PHONY: FORCE
FORCE:
