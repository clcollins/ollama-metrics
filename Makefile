-include .env

CONTAINER_SUBSYS ?= podman
NAME := ollama-metrics
PROJECT := clcollins
IMAGE_REGISTRY := quay.io

CONTAINER_FILE := Containerfile
IMAGE_STRING := $(IMAGE_REGISTRY)/$(PROJECT)/$(NAME)
CI_IMAGE := $(NAME)-ci

GIT_SHA := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_COMMIT := $(shell git rev-parse HEAD 2>/dev/null || echo "unknown")
BUILD_DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
VERSION ?= dev

GO := go
GOFLAGS ?=

# Tool binaries (installed via go install)
GOLANGCI_LINT := $(shell command -v golangci-lint 2>/dev/null)

.PHONY: all
all: fmt vet lint go-test build

# --- Go targets ---

.PHONY: fmt
fmt:
	$(GO) fmt ./...

.PHONY: vet
vet:
	$(GO) vet ./...

.PHONY: lint
lint:
ifdef GOLANGCI_LINT
	$(GOLANGCI_LINT) run ./...
else
	@echo "golangci-lint is required but not installed (install: https://golangci-lint.run/welcome/install/)"
	@exit 1
endif

.PHONY: go-test
go-test:
	$(GO) test -v -count=1 -race ./...

.PHONY: go-test-cover
go-test-cover:
	$(GO) test -cover -count=1 ./...

.PHONY: build
build:
	mkdir -p out
	$(GO) build $(GOFLAGS) -o out/$(NAME) .

.PHONY: tidy
tidy:
	$(GO) mod tidy

.PHONY: tidy-check
tidy-check:
	$(GO) mod tidy
	@if [ -n "$$(git diff --name-only go.mod go.sum)" ]; then \
		echo "go.mod or go.sum is not tidy. Run 'go mod tidy' and commit the changes."; \
		git diff go.mod go.sum; \
		exit 1; \
	fi

# --- Container targets ---

.PHONY: image-build
image-build:
	$(CONTAINER_SUBSYS) build -f $(CONTAINER_FILE) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg VCS_REF=$(GIT_COMMIT) \
		--build-arg VERSION=$(VERSION) \
		-t $(IMAGE_STRING):$(GIT_SHA) -t $(IMAGE_STRING):latest .

.PHONY: image-push
image-push: image-build
	$(CONTAINER_SUBSYS) push $(IMAGE_STRING):$(GIT_SHA)
	$(CONTAINER_SUBSYS) push $(IMAGE_STRING):latest

# --- CI container targets ---

.PHONY: ci-build
ci-build:
	$(CONTAINER_SUBSYS) build -f test/Containerfile.ci -t $(CI_IMAGE) test/

.PHONY: ci-all
ci-all: ci-build
	$(CONTAINER_SUBSYS) run --rm -v $$(pwd):/work:Z $(CI_IMAGE) make ci-checks

.PHONY: ci-checks
ci-checks: yaml-lint markdown-lint makefile-lint containerfile-check kubernetes-validate shellcheck-lint docs-check

# --- CI check targets (run inside CI container) ---

.PHONY: yaml-lint
yaml-lint:
	yamllint -c .yamllint.yaml prometheus/ .github/workflows/

.PHONY: markdown-lint
markdown-lint:
	markdownlint-cli2 '**/*.md' '#node_modules'

.PHONY: makefile-lint
makefile-lint:
	checkmake Makefile

.PHONY: containerfile-check
containerfile-check:
	ENFORCE=1 bash test/scripts/check-containerfile-tags.sh Containerfile
	ENFORCE=1 bash test/scripts/check-containerfile-tags.sh test/Containerfile.ci

.PHONY: kubernetes-validate
kubernetes-validate:
	kubeconform -strict -summary prometheus/monitoring.yaml

.PHONY: shellcheck-lint
shellcheck-lint:
	shellcheck test/scripts/*.sh

.PHONY: docs-check
docs-check:
	@if [ -z "$$(find docs/plans -name '*.md' -type f 2>/dev/null)" ]; then \
		echo "ERROR: No plan documents found in docs/plans/"; \
		exit 1; \
	fi
	@echo "Plan documents found in docs/plans/."

# --- Aggregate targets ---

.PHONY: test
test: ci-all

.PHONY: test-all
test-all: fmt vet lint go-test build tidy-check ci-all image-build
	@echo "All checks passed."

.PHONY: clean
clean:
	rm -rf out/
