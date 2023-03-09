SCRIPT_NAME := muacme

prefix      := /usr/local
bindir      := $(prefix)/bin
datadir     := $(prefix)/share/muacme
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
	$(INSTALL) -m 755 muacme-acmedns $(DESTDIR)$(bindir)/muacme-acmedns
	$(INSTALL) -d $(DESTDIR)$(sysconfdir)/$(SCRIPT_NAME)
	$(INSTALL) -m 644 $(SCRIPT_NAME).conf $(DESTDIR)$(sysconfdir)/$(SCRIPT_NAME)/$(SCRIPT_NAME).conf
	$(INSTALL) -m 755 renew-hook.sh $(DESTDIR)$(sysconfdir)/$(SCRIPT_NAME)/renew-hook.sh
	$(INSTALL) -d $(DESTDIR)$(datadir)
	$(INSTALL) -m 755 acmedns-challenge-hook.sh $(DESTDIR)$(datadir)/acmedns-challenge-hook.sh
	$(INSTALL) -m 755 multi-challenge-hook.sh $(DESTDIR)$(datadir)/multi-challenge-hook.sh
	$(INSTALL) -m 755 httpd-challenge-hook.sh $(DESTDIR)$(datadir)/httpd-challenge-hook.sh
	$(INSTALL) -m 755 nsupdate-challenge-hook.sh $(DESTDIR)$(datadir)/nsupdate-challenge-hook.sh
	$(SED) -E -i "s|/usr/share/muacme/|$(datadir)/|; s|/etc/muacme/|$(sysconfdir)/$(SCRIPT_NAME)/|" \
		$(DESTDIR)$(bindir)/$(SCRIPT_NAME) \
		$(DESTDIR)$(sysconfdir)/$(SCRIPT_NAME)/$(SCRIPT_NAME).conf \
		$(DESTDIR)$(datadir)/*.sh

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
