# Copyright © 2025 OpenCHAMI a Series of LF Projects, LLC
# SPDX-FileCopyrightText: 2025 OpenCHAMI Contributors
#
# SPDX-License-Identifier: MIT

.PHONY: all clean install rpm-build rpm-clean

# Variables
GIT      ?= $(shell command -v git 2>/dev/null)
TAG      ?= $(shell $(GIT) describe --tags --always --dirty)
VERSION  ?= $(shell $(TAG) 2>/dev/null || echo "dev")

# RPM version/release: strip the leading 'v' and drop git-describe's
# '-N-gHASH[-dirty]' suffix (hyphens aren't allowed in an RPM Version
# field anyway). An exact tag like v0.1.2 becomes 0.1.2.
RPM_VERSION ?= $(shell echo "$(VERSION)" | sed -e 's/^v//' -e 's/-.*//')
RPM_RELEASE ?= 1
RPM_TOPDIR ?= $(CURDIR)/dist/rpmbuild
RPM_NAME ?= openchami-postgres-quadlet

# Targets

all: rpm-build

clean: rpm-clean

rpm-build:
	@command -v rpmbuild >/dev/null 2>&1 || { echo "rpmbuild is required but not installed."; exit 1; }
	rm -rf $(RPM_TOPDIR)
	mkdir -p $(RPM_TOPDIR)/SOURCES/$(RPM_NAME)-$(RPM_VERSION)/LICENSES
	cp -rL packaging/rpm-quadlet/systemd/* $(RPM_TOPDIR)/SOURCES/$(RPM_NAME)-$(RPM_VERSION)/
	cp -rL packaging/rpm-quadlet/scripts/* $(RPM_TOPDIR)/SOURCES/$(RPM_NAME)-$(RPM_VERSION)/
	cp LICENSES/MIT.txt $(RPM_TOPDIR)/SOURCES/$(RPM_NAME)-$(RPM_VERSION)/LICENSES/
	tar -C $(RPM_TOPDIR)/SOURCES -czf $(RPM_TOPDIR)/SOURCES/$(RPM_NAME)-$(RPM_VERSION).tar.gz \
		$(RPM_NAME)-$(RPM_VERSION)
	rpmbuild --define "_topdir $(RPM_TOPDIR)" \
		--define "version $(RPM_VERSION)" \
		--define "rel $(RPM_RELEASE)" \
		-bb packaging/rpm-quadlet/$(RPM_NAME).spec
	@echo "Built: $(RPM_TOPDIR)/RPMS/noarch/$$(ls $(RPM_TOPDIR)/RPMS/noarch)"

rpm-clean: ## Remove local RPM build artifacts
	rm -rf $(RPM_TOPDIR)
