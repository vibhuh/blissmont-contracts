# blissmont-contracts — contract tooling.
# These mirror the CI gate in .github/workflows/buf.yml. Install buf 1.47.2 first
# (https://buf.build/docs/installation) or `go install github.com/bufbuild/buf/cmd/buf@v1.47.2`.

BUF_VERSION := 1.47.2

.PHONY: help build lint breaking check

help: ## Show this help.
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-10s %s\n", $$1, $$2}'

build: ## Compile all protos (fails on any parse/import error).
	buf build

lint: ## Run the style gate (BASIC set — see buf.yaml).
	buf lint

breaking: ## Wire-compat gate: compare working tree against the latest release tag.
	@latest="$$(git tag --list 'v*' --sort=-v:refname | head -n1)"; \
	if [ -z "$$latest" ]; then \
		echo "No prior release tag — nothing to compare against."; \
	else \
		echo "Comparing against $$latest"; \
		buf breaking --against ".git#tag=$$latest"; \
	fi

check: build lint breaking ## Run the full local gate (build + lint + breaking).
	@echo "✓ contract checks passed"
