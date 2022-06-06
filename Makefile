DOCKER ?= docker

ifneq ($(FORCE),)
DOCKER_BUILD_OPT ?= --rm --no-cache
else
DOCKER_BUILD_OPT ?= --rm
endif

B = $(CURDIR)

# scripts
#
GET_FILES_SH = $(CURDIR)/scripts/get_files.sh
GET_VARS_SH = $(CURDIR)/scripts/get_vars.sh

GEN_RULES_MK_SH = $(CURDIR)/scripts/gen_rules_mk.sh
GEN_IMAGES_MK_SH = $(CURDIR)/scripts/gen_images_mk.sh
GEN_TAG_DIRS_SH = $(CURDIR)/scripts/gen_tag_dirs.sh

# generated outputs
#
FILES = $(shell $(GET_FILES_SH) Dockerfile)
TEMPLATES = $(addsuffix .in, $(FILES))
IMAGE_MK_VARS = $(shell $(GET_VARS_SH) $(TEMPLATES))

RULES_MK = rules.mk
CONFIG_MK = config.mk
IMAGES_MK = images.mk
TAG_DIRS = .tag-dirs
TAGS_FILE = .tags-current
TAGS_ALL_FILE = .tags-all
TAGS_GC_FILE = .tags-obsolete

.PHONY: all files images pull push push-all clean

all: images

files: $(RULES_MK) $(CONFIG_MK) $(IMAGES_MK) $(TAG_DIRS)

clean:
	rm -f $(B)/.image-* $(RULES_MK) $(IMAGES_MK) $(TAG_DIRS) *~

.PHONY: FORCE
FORCE:

$(RULES_MK): $(GEN_RULES_MK_SH) $(TEMPLATES) Makefile
	$< $(IMAGE_MK_VARS) > $@~
	mv $@~ $@

include $(RULES_MK)
include $(CONFIG_MK)

$(TAG_DIRS): $(GEN_TAG_DIRS_SH) FORCE
	$(GEN_TAG_DIRS_SH) > $@~
	if ! cmp -s $@~ $@; then mv $@~ $@; else rm $@~; fi

$(IMAGES_MK): $(GEN_IMAGES_MK_SH) $(TAG_DIRS) $(CONFIG_MK) Makefile
	$< $(PREFIX) $(TAG_DIRS) > $@~
	mv $@~ $@

include $(IMAGES_MK)

images: files $(IMAGES)
push: files $(PUSHERS)
push-all: files $(ALL_PUSHERS)
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
