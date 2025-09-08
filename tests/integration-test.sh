#!/bin/bash
# Integration tests for macOS ASKPASS
# Tests the complete functionality in various scenarios

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly ASKPASS_BIN="${PROJECT_ROOT}/bin/askpass"
readonly TEMP_CONFIG_DIR="/tmp/askpass-test-$$"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test statistics
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

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

# Test framework functions
test_start() {
    local test_name="$1"
    log_info "Test: $test_name"
    ((TESTS_RUN++))
}

test_pass() {
    local test_name="$1"
    log_success "PASS: $test_name"
    ((TESTS_PASSED++))
}

test_fail() {
    local test_name="$1"
    local reason="${2:-Unknown error}"
    log_error "FAIL: $test_name - $reason"
    ((TESTS_FAILED++))
}

# Setup test environment
setup_test_env() {
    log_info "Setting up test environment..."
    
    # Create temporary config directory
    mkdir -p "$TEMP_CONFIG_DIR"
    export HOME="$TEMP_CONFIG_DIR"
    
    # Clear relevant environment variables
    unset SUDO_PASSWORD CI_SUDO_PASSWORD ASKPASS_DEBUG SUDO_ASKPASS
    
    log_success "Test environment ready"
}

# Cleanup test environment
cleanup_test_env() {
    log_info "Cleaning up test environment..."
    
    # Remove temporary files
    rm -rf "$TEMP_CONFIG_DIR"
    
    # Remove any test keychain entries
    security delete-generic-password -a "$USER" -s "macos-askpass-sudo" 2>/dev/null || true
    
    log_success "Test environment cleaned"
}

# Test 1: Basic functionality
test_basic_functionality() {
    test_start "Basic functionality"
    
    # Test version command
    if ! "$ASKPASS_BIN" version >/dev/null 2>&1; then
        test_fail "Basic functionality" "Version command failed"
        return 1
    fi
    
    # Test help command
    if ! "$ASKPASS_BIN" help >/dev/null 2>&1; then
        test_fail "Basic functionality" "Help command failed"
        return 1
    fi
    
    # Test config command
    if ! "$ASKPASS_BIN" config >/dev/null 2>&1; then
        test_fail "Basic functionality" "Config command failed"
        return 1
    fi
    
    test_pass "Basic functionality"
}

# Test 2: Environment variable password retrieval
test_env_var_password() {
    test_start "Environment variable password"
    
    # Test CI_SUDO_PASSWORD (highest priority)
    export CI_SUDO_PASSWORD="test_ci_password"
    local result
    result=$("$ASKPASS_BIN" 2>/dev/null)
    
    if [[ "$result" != "test_ci_password" ]]; then
        test_fail "Environment variable password" "CI_SUDO_PASSWORD not retrieved correctly"
        return 1
    fi
    
    # Test SUDO_PASSWORD (lower priority, should not override CI_SUDO_PASSWORD)
    export SUDO_PASSWORD="test_sudo_password"
    result=$("$ASKPASS_BIN" 2>/dev/null)
    
    if [[ "$result" != "test_ci_password" ]]; then
        test_fail "Environment variable password" "Password priority incorrect"
        return 1
    fi
    
    # Test SUDO_PASSWORD only
    unset CI_SUDO_PASSWORD
    result=$("$ASKPASS_BIN" 2>/dev/null)
    
    if [[ "$result" != "test_sudo_password" ]]; then
        test_fail "Environment variable password" "SUDO_PASSWORD not retrieved correctly"
        return 1
    fi
    
    unset SUDO_PASSWORD
    test_pass "Environment variable password"
}

# Test 3: Keychain integration
test_keychain_integration() {
    test_start "Keychain integration"
    
    # Store test password in keychain
    if ! echo "test_keychain_password" | security add-generic-password \
        -a "$USER" \
        -s "macos-askpass-sudo" \
        -T "$ASKPASS_BIN" \
        -T "/usr/bin/sudo" \
        -w 2>/dev/null; then
        test_fail "Keychain integration" "Failed to store password in keychain"
        return 1
    fi
    
    # Retrieve password from keychain
    local result
    result=$("$ASKPASS_BIN" 2>/dev/null)
    
    if [[ "$result" != "test_keychain_password" ]]; then
        test_fail "Keychain integration" "Failed to retrieve password from keychain"
        return 1
    fi
    
    # Clean up keychain entry
    security delete-generic-password -a "$USER" -s "macos-askpass-sudo" 2>/dev/null || true
    
    test_pass "Keychain integration"
}

# Test 4: ASKPASS with sudo (requires user password)
test_sudo_integration() {
    test_start "Sudo integration"
    
    # Skip if no password available for testing
    if [[ -z "${TEST_SUDO_PASSWORD:-}" ]]; then
        log_warning "Skipping sudo integration test (no TEST_SUDO_PASSWORD set)"
        return 0
    fi
    
    # Set up ASKPASS environment
    export CI_SUDO_PASSWORD="$TEST_SUDO_PASSWORD"
    export SUDO_ASKPASS="$ASKPASS_BIN"
    
    # Test sudo with ASKPASS
    if ! timeout 10s sudo -A true 2>/dev/null; then
        test_fail "Sudo integration" "sudo -A failed"
        return 1
    fi
    
    unset CI_SUDO_PASSWORD SUDO_ASKPASS
    test_pass "Sudo integration"
}

# Test 5: Error handling
test_error_handling() {
    test_start "Error handling"
    
    # Test with no password sources available
    local result
    result=$("$ASKPASS_BIN" 2>/dev/null || echo "FAILED")
    
    if [[ "$result" != "" ]]; then
        test_fail "Error handling" "Should return empty string when no password available"
        return 1
    fi
    
    # Test invalid command
    if "$ASKPASS_BIN" invalid_command >/dev/null 2>&1; then
        test_fail "Error handling" "Should fail on invalid command"
        return 1
    fi
    
    test_pass "Error handling"
}

# Test 6: Debug mode
test_debug_mode() {
    test_start "Debug mode"
    
    export ASKPASS_DEBUG=1
    export SUDO_PASSWORD="test_debug"
    
    # Capture stderr output
    local debug_output
    debug_output=$("$ASKPASS_BIN" 2>&1 >/dev/null)
    
    if [[ "$debug_output" != *"ASKPASS DEBUG"* ]]; then
        test_fail "Debug mode" "Debug output not generated"
        return 1
    fi
    
    unset ASKPASS_DEBUG SUDO_PASSWORD
    test_pass "Debug mode"
}

# Test 7: Store and remove commands
test_store_remove() {
    test_start "Store and remove commands"
    
    # Test store command (interactive, so we'll simulate)
    # This is a basic test that the command exists and doesn't crash
    if ! "$ASKPASS_BIN" help | grep -q "store"; then
        test_fail "Store and remove commands" "Store command not available"
        return 1
    fi
    
    if ! "$ASKPASS_BIN" help | grep -q "remove"; then
        test_fail "Store and remove commands" "Remove command not available"
        return 1
    fi
    
    # Test remove command (should handle non-existent entries gracefully)
    if ! "$ASKPASS_BIN" remove 2>/dev/null; then
        # It's okay if this fails, as there might not be anything to remove
        log_warning "Remove command returned non-zero (expected if no password stored)"
    fi
    
    test_pass "Store and remove commands"
}

# Test 8: Configuration display
test_config_display() {
    test_start "Configuration display"
    
    # Test that config command shows expected sections
    local config_output
    config_output=$("$ASKPASS_BIN" config 2>&1)
    
    if [[ "$config_output" != *"macOS ASKPASS Configuration"* ]]; then
        test_fail "Configuration display" "Config header not found"
        return 1
    fi
    
    if [[ "$config_output" != *"Password Sources"* ]]; then
        test_fail "Configuration display" "Password sources section not found"
        return 1
    fi
    
    test_pass "Configuration display"
}

# Test 9: Performance test
test_performance() {
    test_start "Performance test"
    
    export SUDO_PASSWORD="performance_test"
    
    # Time 100 password retrievals
    local start_time end_time duration
    start_time=$(date +%s.%N)
    
    for i in {1..100}; do
        "$ASKPASS_BIN" >/dev/null 2>&1
    done
    
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l)
    
    # Should complete in reasonable time (less than 10 seconds for 100 calls)
    if (( $(echo "$duration > 10" | bc -l) )); then
        test_fail "Performance test" "Too slow: ${duration}s for 100 calls"
        return 1
    fi
    
    log_info "Performance: 100 calls in ${duration}s"
    unset SUDO_PASSWORD
    test_pass "Performance test"
}

# Test 10: Concurrent access
test_concurrent_access() {
    test_start "Concurrent access"
    
    export SUDO_PASSWORD="concurrent_test"
    
    # Run multiple askpass instances in parallel
    local pids=()
    for i in {1..10}; do
        "$ASKPASS_BIN" >/dev/null 2>&1 &
        pids+=($!)
    done
    
    # Wait for all to complete
    local failed=0
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            ((failed++))
        fi
    done
    
    if [[ $failed -gt 0 ]]; then
        test_fail "Concurrent access" "$failed out of 10 concurrent calls failed"
        return 1
    fi
    
    unset SUDO_PASSWORD
    test_pass "Concurrent access"
}

# Run all tests
run_all_tests() {
    log_info "Starting macOS ASKPASS integration tests..."
    echo
    
    # Setup
    setup_test_env
    
    # Run tests
    test_basic_functionality
    test_env_var_password
    test_keychain_integration
    test_sudo_integration
    test_error_handling
    test_debug_mode
    test_store_remove
    test_config_display
    
    # Performance tests (optional)
    if command -v bc >/dev/null 2>&1; then
        test_performance
        test_concurrent_access
    else
        log_warning "Skipping performance tests (bc not available)"
    fi
    
    # Cleanup
    cleanup_test_env
    
    # Results
    echo
    log_info "Test Results:"
    echo "  Total tests run: $TESTS_RUN"
    echo "  Tests passed:    $TESTS_PASSED"
    echo "  Tests failed:    $TESTS_FAILED"
    echo
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed! 🎉"
        return 0
    else
        log_error "Some tests failed"
        return 1
    fi
}

# Help function
show_help() {
    cat << EOF
macOS ASKPASS Integration Test Suite

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --help, -h          Show this help
    --sudo-test         Enable sudo integration test (requires TEST_SUDO_PASSWORD)
    --verbose           Enable verbose output

ENVIRONMENT VARIABLES:
    TEST_SUDO_PASSWORD  Password for sudo integration test

EXAMPLES:
    # Run basic tests
    $0
    
    # Run tests including sudo integration
    TEST_SUDO_PASSWORD="your_password" $0 --sudo-test
    
    # Verbose output
    $0 --verbose

EOF
}

# Main execution
main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --sudo-test)
                ENABLE_SUDO_TEST=1
                shift
                ;;
            --verbose)
                set -x
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Check if askpass binary exists
    if [[ ! -x "$ASKPASS_BIN" ]]; then
        log_error "ASKPASS binary not found or not executable: $ASKPASS_BIN"
        exit 1
    fi
    
    # Run tests
    run_all_tests
}

# Execute main function
main "$@"