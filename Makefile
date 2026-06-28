GO ?= go
GOFMT ?= gofmt
YAMLFMT ?= yamlfmt
ACTIONLINT ?= actionlint
SHFMT ?= shfmt
SHELLCHECK ?= shellcheck
HADOLINT ?= hadolint
GITLEAKS ?= gitleaks
RENOVATE ?= npx --yes renovate@latest

GO_DIR := images/rdap-fi-proxy
DOCKERFILES := $(shell find images -name Dockerfile -type f | sort)
SHELL_FILES := $(shell find . -path ./.git -prune -o -type f -name '*.sh' -print | sort)

.PHONY: ci
ci: fmt/check lint test security/secrets renovate/check

.PHONY: fmt
fmt: fmt/yaml fmt/go fmt/sh

.PHONY: fmt/yaml
fmt/yaml:
	$(YAMLFMT) .

.PHONY: fmt/go
fmt/go:
	cd $(GO_DIR) && $(GOFMT) -w .

.PHONY: fmt/sh
fmt/sh:
	@if [ -n "$(SHELL_FILES)" ]; then $(SHFMT) -w $(SHELL_FILES); fi

.PHONY: fmt/check
fmt/check: fmt/check-yaml fmt/check-go fmt/check-sh

.PHONY: fmt/check-yaml
fmt/check-yaml:
	$(YAMLFMT) -lint .

.PHONY: fmt/check-go
fmt/check-go:
	cd $(GO_DIR) && test -z "$$($(GOFMT) -l .)"

.PHONY: fmt/check-sh
fmt/check-sh:
	@if [ -n "$(SHELL_FILES)" ]; then $(SHFMT) -d $(SHELL_FILES); fi

.PHONY: lint
lint: lint/actions lint/dockerfile lint/sh lint/go

.PHONY: lint/actions
lint/actions:
	$(ACTIONLINT)

.PHONY: lint/dockerfile
lint/dockerfile:
	$(HADOLINT) $(DOCKERFILES)

.PHONY: lint/sh
lint/sh:
	@if [ -n "$(SHELL_FILES)" ]; then $(SHELLCHECK) $(SHELL_FILES); fi

.PHONY: lint/go
lint/go:
	cd $(GO_DIR) && $(GO) vet ./...

.PHONY: test
test: test/go

.PHONY: test/go
test/go:
	cd $(GO_DIR) && $(GO) test ./...

.PHONY: security/secrets
security/secrets:
	$(GITLEAKS) dir --redact .

.PHONY: renovate/check
renovate/check:
	$(RENOVATE) --platform=local --dry-run=extract --require-config=required --config-validation-error=true --onboarding=false
