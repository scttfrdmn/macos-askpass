#!/bin/bash
# Test for sudo integration to validate the askpass argument bug fix
# This test validates that askpass actually works with sudo -A

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ASKPASS_BIN="${PROJECT_ROOT}/bin/askpass"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Test sudo integration (requires user interaction or password)
test_sudo_integration() {
    log_info "Testing sudo integration with askpass..."

    # Set up ASKPASS environment
    export SUDO_ASKPASS="$ASKPASS_BIN"

    log_info "This test will use the GUI password dialog (if available) or keychain..."
    log_info "You may be prompted to enter your password."

    # Test with a simple command
    if timeout 30s sudo -A true 2>/dev/null; then
        log_success "sudo -A integration test passed!"
        unset SUDO_ASKPASS
        return 0
    else
        log_error "sudo -A integration test failed"
        log_info "This might be because:"
        log_info "  - No password stored in keychain"
        log_info "  - GUI dialog was cancelled"
        log_info "  - Password was incorrect"
        unset SUDO_ASKPASS
        return 1
    fi
}

# Test with environment variable (safe test)
test_env_var_sudo() {
    log_info "Testing sudo with environment variable (safe test)..."

    # This test is safe because it uses a dummy password that won't work
    export SUDO_PASSWORD="dummy_password_for_testing"
    export SUDO_ASKPASS="$ASKPASS_BIN"
    export ASKPASS_DEBUG=1

    log_info "Running sudo with dummy password (should fail authentication but show correct flow)..."

    # Capture the debug output to verify the flow works
    local output
    output=$(sudo -A true 2>&1 || true)

    if [[ "$output" == *"ASKPASS DEBUG: Called by sudo"* ]] &&
       [[ "$output" == *"Using SUDO_PASSWORD environment variable"* ]]; then
        log_success "Argument passing from sudo to askpass works correctly!"
        unset SUDO_PASSWORD SUDO_ASKPASS ASKPASS_DEBUG
        return 0
    else
        log_error "Argument passing test failed"
        echo "Debug output:"
        echo "$output"
        unset SUDO_PASSWORD SUDO_ASKPASS ASKPASS_DEBUG
        return 1
    fi
}

# Main function
main() {
    log_info "Starting sudo integration tests..."
    echo

    local failed=0

    # Test 1: Environment variable flow (always safe)
    if ! test_env_var_sudo; then
        ((failed++))
    fi

    echo

    # Test 2: Real sudo integration (optional, requires password)
    if [[ "${SKIP_INTERACTIVE_TEST:-}" != "1" ]]; then
        log_info "Running interactive sudo test..."
        log_info "You can skip this by setting SKIP_INTERACTIVE_TEST=1"
        echo

        read -p "Do you want to run the interactive sudo test? (y/N): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if ! test_sudo_integration; then
                ((failed++))
            fi
        else
            log_warning "Skipping interactive sudo test"
        fi
    else
        log_warning "Skipping interactive sudo test (SKIP_INTERACTIVE_TEST=1)"
    fi

    echo
    if [[ $failed -eq 0 ]]; then
        log_success "All sudo integration tests completed successfully! 🎉"
        return 0
    else
        log_error "$failed test(s) failed"
        return 1
    fi
}

# Execute main function
main "$@"