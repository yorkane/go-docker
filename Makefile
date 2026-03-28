# =============================================================================
# Makefile - Build, Test, and Deploy yourapp
# =============================================================================

# Variables
APP_NAME := yourapp
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT := $(shell git rev-parse HEAD 2>/dev/null || echo "unknown")
BUILD_DATE := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
BUILD_BY := $(USER)
DOCKER_IMAGE := yourapp
DOCKER_TAG := $(DOCKER_IMAGE):$(VERSION)
DOCKER_LATEST := $(DOCKER_IMAGE):latest
UID := $(shell id -u)
GID := $(shell id -g)

# Build flags for Go
LDFLAGS := -s -w \
	-X main.Version=$(VERSION) \
	-X main.Commit=$(COMMIT) \
	-X main.BuiltAt=$(BUILD_DATE) \
	-X main.BuiltBy=$(BUILD_BY)

# Default target
.PHONY: all
all: lint test build

# =============================================================================
# Development
# =============================================================================

.PHONY: dev
dev: ## Start development environment with docker-compose
	docker compose up --build yourapp-dev

.PHONY: logs
logs: ## Tail application logs
	docker compose logs -f yourapp

.PHONY: shell
shell: ## Get a shell into the running container
	docker compose exec yourapp /bin/bash

# =============================================================================
# Building
# =============================================================================

.PHONY: build
build: ## Build local binary (for Linux x86_64)
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
		-ldflags="$(LDFLAGS)" \
		-o bin/$(APP_NAME)-linux-amd64 \
		./cmd/server

.PHONY: build-all
build-all: ## Build for all platforms
	mkdir -p bin
	GOOS=linux GOARCH=amd64 go build -ldflags="$(LDFLAGS)" -o bin/$(APP_NAME)-linux-amd64 ./cmd/server
	GOOS=linux GOARCH=arm64 go build -ldflags="$(LDFLAGS)" -o bin/$(APP_NAME)-linux-arm64v8 ./cmd/server
	GOOS=darwin GOARCH=amd64 go build -ldflags="$(LDFLAGS)" -o bin/$(APP_NAME)-darwin-amd64 ./cmd/server
	GOOS=darwin GOARCH=arm64 go build -ldflags="$(LDFLAGS)" -o bin/$(APP_NAME)-darwin-arm64 ./cmd/server
	GOOS=windows GOARCH=amd64 go build -ldflags="$(LDFLAGS)" -o bin/$(APP_NAME)-windows-amd64.exe ./cmd/server

.PHONY: docker-build
docker-build: ## Build production Docker image
	docker build \
		--build-arg BUILD_VERSION=$(VERSION) \
		--build-arg BUILD_COMMIT=$(COMMIT) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg BUILD_BY=$(BUILD_BY) \
		--build-arg UID=$(UID) \
		--build-arg GID=$(GID) \
		-t $(DOCKER_TAG) \
		-t $(DOCKER_LATEST) \
		.

.PHONY: docker-build-no-cache
docker-build-no-cache: ## Build Docker image without cache
	docker build --no-cache \
		--build-arg BUILD_VERSION=$(VERSION) \
		--build-arg BUILD_COMMIT=$(COMMIT) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg BUILD_BY=$(BUILD_BY) \
		--build-arg UID=$(UID) \
		--build-arg GID=$(GID) \
		-t $(DOCKER_TAG) \
		-t $(DOCKER_LATEST) \
		.

# =============================================================================
# Testing
# =============================================================================

.PHONY: test
test: ## Run unit tests
	go test -v -race -cover ./...

.PHONY: test-coverage
test-coverage: ## Run tests with coverage report
	go test -v -race -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

.PHONY: lint
lint: ## Run linters (golangci-lint)
	golangci-lint run ./...

# =============================================================================
# Docker Management
# =============================================================================

.PHONY: up
up: ## Start production containers
	docker compose up -d

.PHONY: down
down: ## Stop containers
	docker compose down

.PHONY: restart
restart: down up ## Restart containers

.PHONY: clean
clean: ## Remove containers, volumes, and build artifacts
	docker compose down -v
	rm -rf bin/ coverage.out coverage.html

.PHONY: re
re: clean up ## Clean and restart

# =============================================================================
# Image Management
# =============================================================================

.PHONY: push
push: ## Push images to registry
	docker push $(DOCKER_TAG)
	docker push $(DOCKER_LATEST)

.PHONY: pull
pull: ## Pull images from registry
	docker pull $(DOCKER_TAG)

.PHONY: image-info
image-info: ## Show image info
	@echo "App:    $(APP_NAME)"
	@echo "Version: $(VERSION)"
	@echo "Commit:  $(COMMIT)"
	@echo "Build:   $(BUILD_DATE)"
	@echo "By:      $(BUILD_BY)"

# =============================================================================
# Security
# =============================================================================

.PHONY: security-scan
security-scan: ## Run security scans
	docker run --rm -v $(shell pwd):/workspace aquasec/trivy:latest image $(DOCKER_TAG)

.PHONY: check-secrets
check-secrets: ## Scan for secrets in codebase
	@echo "Scanning for secrets..."
	gitleaks detect --source . --report-path gitleaks-report.json

# =============================================================================
# Help
# =============================================================================

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'
