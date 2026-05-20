SHELL := /usr/bin/env bash
PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin

.PHONY: test lint check install uninstall

test:
	bash tests/smoke_test.sh

lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck rom_cleanup.sh tests/smoke_test.sh; \
	else \
		echo "shellcheck not installed; skipping lint"; \
	fi

check: test lint

install:
	install -d "$(BINDIR)"
	install -m 0755 rom_cleanup.sh "$(BINDIR)/rom-cleanup"
	@printf 'Installed to %s/rom-cleanup\n' "$(BINDIR)"

uninstall:
	rm -f "$(BINDIR)/rom-cleanup"
	@printf 'Removed %s/rom-cleanup\n' "$(BINDIR)"
