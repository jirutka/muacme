SCRIPT_NAME := muacme

prefix      := /usr/local
bindir      := $(prefix)/bin
sysconfdir  := /etc

INSTALL     := install
SED         := sed

ifeq ($(shell uname -s),Darwin)
    SED     := gsed
endif

MAKEFILE_PATH  = $(lastword $(MAKEFILE_LIST))


all: help

#: Install into $DESTDIR.
install:
	$(INSTALL) -d $(DESTDIR)$(bindir)
	$(INSTALL) -m 755 $(SCRIPT_NAME) $(DESTDIR)$(bindir)/$(SCRIPT_NAME)
	$(INSTALL) -d $(DESTDIR)$(sysconfdir)/$(SCRIPT_NAME)
	$(INSTALL) -m 644 $(SCRIPT_NAME).conf $(DESTDIR)$(sysconfdir)/$(SCRIPT_NAME)/$(SCRIPT_NAME).conf

#: Update version in the script and README.adoc to $VERSION.
bump-version:
	test -n "$(VERSION)"  # $$VERSION
	$(SED) -E -i "s/^(readonly VERSION)=.*/\1='$(VERSION)'/" $(SCRIPT_NAME)
	$(SED) -E -i "s/^(:version:).*/\1 $(VERSION)/" README.adoc

#: Bump version to $VERSION, create release commit and tag.
release: .check-git-clean | bump-version
	test -n "$(VERSION)"  # $$VERSION
	git add .
	git commit -m "Release version $(VERSION)"
	git tag -s v$(VERSION) -m v$(VERSION)

#: Print list of targets.
help:
	@printf '%s\n\n' 'List of targets:'
	@$(SED) -En '/^#:.*/{ N; s/^#: (.*)\n([A-Za-z0-9_-]+).*/\2 \1/p }' $(MAKEFILE_PATH) \
		| while read label desc; do printf '%-30s %s\n' "$$label" "$$desc"; done

.check-git-clean:
	@test -z "$(shell git status --porcelain)" \
		|| { echo 'You have uncommitted changes!' >&2; exit 1; }

.PHONY: bump-version install release help .check-git-clean
