DOCKER ?= docker

# Multi-architecture support
BUILDER ?= multiarch-native

ifneq ($(BUILDER),)
BUILDER_OPT = --builder $(BUILDER)
else
BUILDER_OPT =
endif

DOCKER_TAG ?= $(DOCKER) buildx imagetools create $(BUILDER_OPT)

DOCKER_BUILD ?= $(DOCKER) buildx build $(BUILDER_OPT)

ifneq ($(FORCE),)
DOCKER_BUILD_OPT ?= --progress=plain --no-cache
else
DOCKER_BUILD_OPT ?= --progress=plain
endif

# Build mode. With no buildx builder we build for the host alone and load the
# image into the local daemon untagged (its ID is recorded in the sentinel);
# with a builder we push the multi-arch manifest under the registry prefix and
# retag its aliases. The generated recipes branch on WANTS_TAGS with ifeq.
ifeq ($(BUILDER),)
WANTS_TAGS ?=
else
WANTS_TAGS ?= 1
endif

# Sentinel suffix, empty in the publish mode. The two modes record different
# things — an image ID in the local daemon against a manifest pushed to the
# registry — so they name their sentinels apart and neither can satisfy the
# other's target. Both remain .image-*/.alias-*, so clean and .gitignore need
# no adjustment.
ifeq ($(WANTS_TAGS),1)
SENTINEL_SUFFIX =
else
SENTINEL_SUFFIX = .local
endif

B = $(CURDIR)

# Recipes that report for themselves are run quietly; V=1 shows them.
Q = $(if $(V),,@)

# Rebuild triggers shared by every image. Depend on the images.mk
# generator, not its output: a change to the build recipe forces a
# full rebuild, but merely regenerating the rule set (a new Dockerfile,
# an added COPY) does not — those land per-image via the explicit file
# prerequisites and the base sentinel edges.
BUILD_SYS = Makefile $(CONFIG_MK) $(GEN_IMAGES_MK_SH)

# scripts
#
GET_FILES_SH = $(CURDIR)/scripts/get_files.sh
GET_VARS_SH = $(CURDIR)/scripts/get_vars.sh

GEN_RULES_MK_SH = $(CURDIR)/scripts/gen_rules_mk.sh
GEN_IMAGES_MK_SH = $(CURDIR)/scripts/gen_images_mk.sh
GEN_TAG_DIRS_SH = $(CURDIR)/scripts/gen_tag_dirs.sh
GEN_ENTRYPOINT_SH = $(CURDIR)/scripts/gen_entrypoint.sh

# Name a generated file the way the reader would type it, since a target
# under $(B) arrives absolute.
relname = $(patsubst $(CURDIR)/%,%,$(1))

# settle,<file>,<command>[,diff]
#
# Run the command with its output captured beside <file>, and put it in
# place only when the content really changed — a generator that says the
# same thing twice leaves the mtime, and every rule waiting on it, alone.
# A third argument shows the change as a unified diff first.
#
#	$(call settle,$@,$(GEN_TAG_DIRS_SH))
#
define settle
$(Q)$(2) > $(1)~ || { rc=$$?; rm -f $(1)~; exit $$rc; }; \
if [ ! -e $(1) ]; then \
	mv $(1)~ $(1); \
	echo "  created   $(call relname,$(1))"; \
elif cmp -s $(1)~ $(1); then \
	rm $(1)~; \
	echo "  unchanged $(call relname,$(1))"; \
else \
	$(if $(3),diff -u --label "$(call relname,$(1))" --label "$(call relname,$(1)) (new)" $(1) $(1)~ || true;) \
	mv $(1)~ $(1); \
	echo "  updated   $(call relname,$(1))"; \
fi
endef

# generated outputs
#
FILES = $(shell $(GET_FILES_SH) Dockerfile)
TEMPLATES = $(addsuffix .in, $(FILES))
IMAGE_MK_VARS = $(shell $(GET_VARS_SH) $(TEMPLATES))

RULES_MK = rules.mk
CONFIG_MK = config.mk
IMAGES_MK = images.mk
ENTRYPOINT_MK = entrypoint.mk
TAG_DIRS = .tag-dirs
TAGS_FILE = .tags-current
TAGS_ALL_FILE = .tags-all
TAGS_GC_FILE = .tags-obsolete

.PHONY: all files images pull push push-all clean

all: images

files: $(RULES_MK) $(CONFIG_MK) $(IMAGES_MK) $(ENTRYPOINT_MK) $(TAG_DIRS)

clean:
	rm -f $(B)/.image-* $(B)/.alias-* $(B)/.link-* $(RULES_MK) $(IMAGES_MK) $(ENTRYPOINT_MK) $(TAG_DIRS) *~

.PHONY: FORCE
FORCE:

$(RULES_MK): $(GEN_RULES_MK_SH) $(TEMPLATES) Makefile
	$< $(IMAGE_MK_VARS) > $@~
	mv $@~ $@

include $(RULES_MK)
include $(CONFIG_MK)

$(TAG_DIRS): $(GEN_TAG_DIRS_SH) FORCE
	$(call settle,$@,$(GEN_TAG_DIRS_SH))

$(IMAGES_MK): $(GEN_IMAGES_MK_SH) $(TAG_DIRS) FORCE
	$(call settle,$@,$< $(PREFIX) $(TAG_DIRS),diff)

# Generate entrypoint.mk with copy rules from golden sources
$(ENTRYPOINT_MK): $(GEN_ENTRYPOINT_SH) FORCE
	$(call settle,$@,$(GEN_ENTRYPOINT_SH),diff)

include $(IMAGES_MK)
include $(ENTRYPOINT_MK)

images: files $(IMAGES)
push: images
push-all: images
pull: files $(PULLERS)

.PHONY: tags tags-to-delete

# garbage collection
#
.PHONY: tags-gc

tags-gc: $(TAGS_GC_FILE)
	while read tag; do \
		$(DOCKER) image rmi "$$tag"; \
	done < $^

$(TAGS_FILE): images FORCE
	@while read t d; do \
		echo \$(PREFIX)$$t; \
		\$(SCRIPTS)/get_aliases.sh \$(PREFIX)$$t; \
	done < $(TAG_DIRS) | sort -uV > $@~
	mv $@~ $@

$(TAGS_ALL_FILE): FORCE
	$(DOCKER) images | grep \
		-e "^$(PREFIX)docker-[^ ]\+-builder " | sed -e 's|^\([^ ]\+\)[ ]\+\([^ ]\+\)[ ]\+\([^ ]\+\) .*|\1:\2\t\3|g' \
		| sort -uV > $@~
	mv $@~ $@

$(TAGS_GC_FILE): $(TAGS_FILE) $(TAGS_ALL_FILE)
	\$(SCRIPTS)/filter-out-tags.sh $(TAGS_FILE) < $(TAGS_ALL_FILE) > $@~
	mv $@~ $@
