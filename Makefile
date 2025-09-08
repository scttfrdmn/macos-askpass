# macOS ASKPASS Makefile
# https://github.com/scttfrdmn/macos-askpass

# Variables
BINARY_NAME=askpass
VERSION=$(shell grep 'readonly ASKPASS_VERSION=' bin/askpass | cut -d'"' -f2)
INSTALL_DIR=/usr/local/bin
CONFIG_DIR=$(HOME)/.config/macos-askpass

.PHONY: help install uninstall test test-local test-ci clean setup dev lint check release

# Default target
all: help

help: ## Show this help message
	@echo 'macOS ASKPASS v$(VERSION)'
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## Install askpass to system (/usr/local/bin)
	@echo "Installing $(BINARY_NAME) v$(VERSION)..."
	@./install.sh install

uninstall: ## Remove askpass from system
	@echo "Uninstalling $(BINARY_NAME)..."
	@./install.sh uninstall

install-local: ## Install askpass to local directory (~/bin)
	@echo "Installing $(BINARY_NAME) to local directory..."
	@mkdir -p $(HOME)/bin
	@cp bin/$(BINARY_NAME) $(HOME)/bin/
	@chmod +x $(HOME)/bin/$(BINARY_NAME)
	@echo "✅ Installed to $(HOME)/bin/$(BINARY_NAME)"
	@echo "   Add $(HOME)/bin to your PATH if not already included"

test: ## Test askpass functionality
	@echo "🧪 Testing $(BINARY_NAME) functionality..."
	@bin/$(BINARY_NAME) test

test-local: ## Test local installation
	@echo "🧪 Testing local installation..."
	@if command -v askpass >/dev/null 2>&1; then \
		askpass test; \
	else \
		echo "❌ askpass not found in PATH. Install first with 'make install'"; \
		exit 1; \
	fi

test-ci: ## Test CI/CD functionality with environment variables
	@echo "🚀 Testing CI/CD functionality..."
	@if [ -z "$(TEST_PASSWORD)" ]; then \
		echo "❌ TEST_PASSWORD environment variable not set"; \
		echo "   Run with: make test-ci TEST_PASSWORD=your_password"; \
		exit 1; \
	fi
	@CI_SUDO_PASSWORD="$(TEST_PASSWORD)" bin/$(BINARY_NAME) test

setup: ## Interactive setup (local installation required)
	@echo "🔧 Running interactive setup..."
	@if command -v askpass >/dev/null 2>&1; then \
		askpass setup; \
	else \
		echo "❌ askpass not found in PATH. Install first with 'make install'"; \
		exit 1; \
	fi

config: ## Show current configuration
	@echo "📋 Current configuration:"
	@if command -v askpass >/dev/null 2>&1; then \
		askpass config; \
	else \
		echo "❌ askpass not found in PATH. Install first with 'make install'"; \
		exit 1; \
	fi

lint: ## Check script syntax and style
	@echo "🔍 Linting scripts..."
	@bash -n bin/$(BINARY_NAME)
	@bash -n install.sh
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck bin/$(BINARY_NAME) install.sh; \
	else \
		echo "⚠️  shellcheck not available, skipping style check"; \
		echo "   Install with: brew install shellcheck"; \
	fi

check: lint test ## Run all checks (lint + test)
	@echo "✅ All checks completed successfully"

clean: ## Clean temporary files and caches
	@echo "🧹 Cleaning temporary files..."
	@rm -f /tmp/askpass-*
	@rm -rf build/ dist/
	@echo "✅ Cleanup complete"

dev: install-local test ## Development cycle: install locally and test
	@echo "🚀 Development setup complete"
	@echo "   askpass installed to $(HOME)/bin/"
	@echo "   All tests passed"

# Demo targets
demo-local: ## Demo local usage
	@echo "🎬 Demo: Local usage"
	@echo "   1. Setting up environment..."
	@echo "export SUDO_ASKPASS=\$$(which askpass)"
	@echo "export SUDO_PASSWORD=\"demo_password\""
	@echo ""
	@echo "   2. Testing sudo with ASKPASS..."
	@echo "sudo -A echo 'ASKPASS demo working!'"

demo-ci: ## Demo CI/CD usage
	@echo "🎬 Demo: CI/CD usage"
	@echo ""
	@echo "# In your CI/CD pipeline:"
	@echo "export CI_SUDO_PASSWORD=\"\$${{ secrets.SUDO_PASSWORD }}\""
	@echo "export SUDO_ASKPASS=\$$(which askpass)"
	@echo "sudo -A make test"
	@echo ""
	@echo "# GitHub Actions example:"
	@echo "- name: Run tests with ASKPASS"
	@echo "  env:"
	@echo "    CI_SUDO_PASSWORD: \$${{ secrets.MACOS_SUDO_PASSWORD }}"
	@echo "  run: |"
	@echo "    export SUDO_ASKPASS=\$$(which askpass)"
	@echo "    sudo -A make integration-test"

# Release targets
build: ## Build distribution package
	@echo "📦 Building release package..."
	@mkdir -p dist
	@cp bin/$(BINARY_NAME) dist/
	@cp install.sh dist/
	@cp README.md dist/ 2>/dev/null || echo "README.md not found, skipping"
	@cp LICENSE dist/ 2>/dev/null || echo "LICENSE not found, skipping"
	@cd dist && tar -czf $(BINARY_NAME)-$(VERSION)-macos.tar.gz *
	@echo "✅ Release package created: dist/$(BINARY_NAME)-$(VERSION)-macos.tar.gz"

release: clean lint test build ## Create release (clean, lint, test, build)
	@echo "🚀 Release $(VERSION) created successfully!"
	@echo "   Package: dist/$(BINARY_NAME)-$(VERSION)-macos.tar.gz"

# Homebrew formula generation
homebrew-formula: ## Generate Homebrew formula template
	@echo "🍺 Generating Homebrew formula template..."
	@mkdir -p Formula
	@echo 'class MacosAskpass < Formula' > Formula/$(BINARY_NAME).rb
	@echo '  desc "Secure ASKPASS implementation for macOS CI/CD and automation"' >> Formula/$(BINARY_NAME).rb
	@echo '  homepage "https://github.com/scttfrdmn/macos-askpass"' >> Formula/$(BINARY_NAME).rb
	@echo '  url "https://github.com/scttfrdmn/macos-askpass/archive/v$(VERSION).tar.gz"' >> Formula/$(BINARY_NAME).rb
	@echo '  sha256 "UPDATE_SHA256_HERE"' >> Formula/$(BINARY_NAME).rb
	@echo '  ' >> Formula/$(BINARY_NAME).rb
	@echo '  def install' >> Formula/$(BINARY_NAME).rb
	@echo '    bin.install "bin/askpass"' >> Formula/$(BINARY_NAME).rb
	@echo '  end' >> Formula/$(BINARY_NAME).rb
	@echo '  ' >> Formula/$(BINARY_NAME).rb
	@echo '  test do' >> Formula/$(BINARY_NAME).rb
	@echo '    system "#{bin}/askpass", "version"' >> Formula/$(BINARY_NAME).rb
	@echo '  end' >> Formula/$(BINARY_NAME).rb
	@echo 'end' >> Formula/$(BINARY_NAME).rb
	@echo "✅ Homebrew formula template created: Formula/$(BINARY_NAME).rb"
	@echo "   Remember to update SHA256 hash after creating release"

# Documentation targets
docs: ## Generate documentation
	@echo "📚 Generating documentation..."
	@mkdir -p docs
	@bin/$(BINARY_NAME) help > docs/USAGE.txt
	@echo "✅ Documentation generated in docs/"

# Version management
version: ## Show version information
	@echo "macOS ASKPASS Version Information"
	@echo "================================"
	@echo "Current version: $(VERSION)"
	@echo "Binary location: bin/$(BINARY_NAME)"
	@echo "Install location: $(INSTALL_DIR)/$(BINARY_NAME)"
	@echo "Config directory: $(CONFIG_DIR)"

# Development utilities
watch: ## Watch for changes and run tests (requires entr)
	@if command -v entr >/dev/null 2>&1; then \
		echo "👀 Watching for changes... (press Ctrl+C to stop)"; \
		find bin/ -name "*.sh" | entr make test; \
	else \
		echo "❌ entr not found. Install with: brew install entr"; \
		exit 1; \
	fi

# Quick development commands
quick-test: ## Quick syntax check and basic test
	@bash -n bin/$(BINARY_NAME) && echo "✅ Syntax OK"
	@bin/$(BINARY_NAME) version >/dev/null && echo "✅ Version OK"

# Show project status
status: ## Show project status
	@echo "macOS ASKPASS Project Status"
	@echo "==========================="
	@echo "Version: $(VERSION)"
	@echo "Script: $(shell ls -la bin/$(BINARY_NAME) | awk '{print $$1, $$3, $$4, $$5}')"
	@echo "Installer: $(shell ls -la install.sh | awk '{print $$1, $$3, $$4, $$5}')"
	@echo ""
	@echo "Installation status:"
	@if command -v askpass >/dev/null 2>&1; then \
		echo "  ✅ Installed: $$(which askpass)"; \
		echo "  📍 Version: $$(askpass version | head -1)"; \
	else \
		echo "  ❌ Not installed in PATH"; \
	fi
	@echo ""
	@echo "Configuration:"
	@if [ -d "$(CONFIG_DIR)" ]; then \
		echo "  ✅ Config directory exists: $(CONFIG_DIR)"; \
		ls -la "$(CONFIG_DIR)" 2>/dev/null | sed 's/^/    /' || true; \
	else \
		echo "  ❌ Config directory not found: $(CONFIG_DIR)"; \
	fi