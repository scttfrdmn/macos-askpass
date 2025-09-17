#!/bin/bash
# Test for the askpass argument handling bug fix
# This test validates that askpass works correctly when called with arguments from sudo

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ASKPASS_BIN="${PROJECT_ROOT}/bin/askpass"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Test 1: Askpass with no arguments (traditional usage)
test_no_arguments() {
    log_info "Testing askpass with no arguments..."

    export SUDO_PASSWORD="test_password_123"
    local result
    result=$("$ASKPASS_BIN" 2>/dev/null)

    if [[ "$result" != "test_password_123" ]]; then
        log_error "Failed: Expected 'test_password_123', got '$result'"
        return 1
    fi

    unset SUDO_PASSWORD
    log_success "No arguments test passed"
    return 0
}

# Test 2: Askpass with "Password:" argument (sudo usage)
test_with_password_prompt() {
    log_info "Testing askpass with 'Password:' argument..."

    export SUDO_PASSWORD="test_password_456"
    local result
    result=$("$ASKPASS_BIN" "Password:" 2>/dev/null)

    if [[ "$result" != "test_password_456" ]]; then
        log_error "Failed: Expected 'test_password_456', got '$result'"
        return 1
    fi

    unset SUDO_PASSWORD
    log_success "'Password:' argument test passed"
    return 0
}

# Test 3: Askpass with custom prompt (sudo usage)
test_with_custom_prompt() {
    log_info "Testing askpass with custom prompt argument..."

    export SUDO_PASSWORD="test_password_789"
    local result
    result=$("$ASKPASS_BIN" "Password for user:" 2>/dev/null)

    if [[ "$result" != "test_password_789" ]]; then
        log_error "Failed: Expected 'test_password_789', got '$result'"
        return 1
    fi

    unset SUDO_PASSWORD
    log_success "Custom prompt test passed"
    return 0
}

# Test 4: Askpass commands still work
test_commands_still_work() {
    log_info "Testing that commands still work..."

    # Test version command
    if ! "$ASKPASS_BIN" version >/dev/null 2>&1; then
        log_error "Version command failed"
        return 1
    fi

    # Test help command
    if ! "$ASKPASS_BIN" help >/dev/null 2>&1; then
        log_error "Help command failed"
        return 1
    fi

    # Test config command
    if ! "$ASKPASS_BIN" config >/dev/null 2>&1; then
        log_error "Config command failed"
        return 1
    fi

    log_success "Commands test passed"
    return 0
}

# Test 5: Environment variable priority
test_env_priority() {
    log_info "Testing environment variable priority..."

    export CI_SUDO_PASSWORD="ci_password"
    export SUDO_PASSWORD="sudo_password"

    local result
    result=$("$ASKPASS_BIN" "Password:" 2>/dev/null)

    if [[ "$result" != "ci_password" ]]; then
        log_error "Failed: Expected 'ci_password', got '$result'"
        return 1
    fi

    unset CI_SUDO_PASSWORD
    result=$("$ASKPASS_BIN" "Password:" 2>/dev/null)

    if [[ "$result" != "sudo_password" ]]; then
        log_error "Failed: Expected 'sudo_password', got '$result'"
        return 1
    fi

    unset SUDO_PASSWORD
    log_success "Environment priority test passed"
    return 0
}

# Run all tests
main() {
    log_info "Starting askpass argument handling tests..."
    echo

    local failed=0

    if ! test_no_arguments; then
        ((failed++))
    fi

    if ! test_with_password_prompt; then
        ((failed++))
    fi

    if ! test_with_custom_prompt; then
        ((failed++))
    fi

    if ! test_commands_still_work; then
        ((failed++))
    fi

    if ! test_env_priority; then
        ((failed++))
    fi

    echo
    if [[ $failed -eq 0 ]]; then
        log_success "All askpass argument handling tests passed! 🎉"
        return 0
    else
        log_error "$failed test(s) failed"
        return 1
    fi
}

# Execute main function
main "$@"