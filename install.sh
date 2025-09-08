#!/bin/bash
# macOS ASKPASS Installation Script
# https://github.com/scttfrdmn/macos-askpass

set -euo pipefail

# Configuration
readonly INSTALL_DIR="/usr/local/bin"
readonly SCRIPT_NAME="askpass"
readonly REPO_URL="https://github.com/scttfrdmn/macos-askpass"
readonly VERSION="1.0.0"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

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

# Check if running on macOS
check_platform() {
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script is designed for macOS only"
        exit 1
    fi
    
    log_success "Platform: macOS $(sw_vers -productVersion)"
}

# Check for required commands
check_dependencies() {
    local missing=()
    
    for cmd in curl security sudo; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing[*]}"
        exit 1
    fi
    
    log_success "All dependencies available"
}

# Check if user has sudo privileges
check_sudo() {
    log_info "Checking sudo privileges..."
    
    if ! sudo -n true 2>/dev/null; then
        log_info "This installation requires sudo privileges"
        log_info "You may be prompted for your password"
        
        if ! sudo true; then
            log_error "Unable to obtain sudo privileges"
            exit 1
        fi
    fi
    
    log_success "Sudo privileges confirmed"
}

# Download and install askpass
install_askpass() {
    log_info "Installing macOS ASKPASS v${VERSION}..."
    
    # Create temporary directory
    local temp_dir
    temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" EXIT
    
    local askpass_path="${temp_dir}/${SCRIPT_NAME}"
    
    # Download from GitHub or use local file
    if [[ -f "bin/askpass" ]]; then
        log_info "Using local askpass script..."
        cp "bin/askpass" "$askpass_path"
    else
        log_info "Downloading askpass from GitHub..."
        if ! curl -fsSL "${REPO_URL}/raw/main/bin/askpass" -o "$askpass_path"; then
            log_error "Failed to download askpass script"
            exit 1
        fi
    fi
    
    # Verify the script
    if [[ ! -f "$askpass_path" ]] || [[ ! -s "$askpass_path" ]]; then
        log_error "Downloaded script is missing or empty"
        exit 1
    fi
    
    # Check if the script is valid
    if ! bash -n "$askpass_path"; then
        log_error "Downloaded script has syntax errors"
        exit 1
    fi
    
    # Make executable
    chmod +x "$askpass_path"
    
    # Install to system location
    local install_path="${INSTALL_DIR}/${SCRIPT_NAME}"
    
    log_info "Installing to ${install_path}..."
    sudo cp "$askpass_path" "$install_path"
    sudo chmod +x "$install_path"
    
    # Verify installation
    if [[ -x "$install_path" ]]; then
        log_success "askpass installed successfully!"
        
        # Test the installation
        if "$install_path" version >/dev/null 2>&1; then
            log_success "Installation verified"
        else
            log_warning "Installation completed but verification failed"
        fi
    else
        log_error "Installation failed"
        exit 1
    fi
}

# Show post-installation instructions
show_instructions() {
    log_success "Installation complete!"
    echo
    echo "🚀 Getting Started:"
    echo "  askpass setup          # Interactive configuration"
    echo "  askpass test           # Test functionality"
    echo "  askpass help           # Show all commands"
    echo
    echo "💡 Quick Examples:"
    echo "  # Set up for local development"
    echo "  askpass setup"
    echo
    echo "  # Use with sudo"
    echo "  export SUDO_ASKPASS=\$(which askpass)"
    echo "  sudo -A echo \"Hello, world!\""
    echo
    echo "  # CI/CD usage"
    echo "  export CI_SUDO_PASSWORD=\"\${{ secrets.SUDO_PASSWORD }}\""
    echo "  export SUDO_ASKPASS=\$(which askpass)"
    echo "  sudo -A make test"
    echo
    echo "📚 Documentation: ${REPO_URL}"
    echo
    log_info "Run 'askpass setup' to get started!"
}

# Uninstall function
uninstall_askpass() {
    log_info "Uninstalling macOS ASKPASS..."
    
    local install_path="${INSTALL_DIR}/${SCRIPT_NAME}"
    
    if [[ -f "$install_path" ]]; then
        sudo rm -f "$install_path"
        log_success "askpass removed from ${INSTALL_DIR}"
    else
        log_warning "askpass not found in ${INSTALL_DIR}"
    fi
    
    # Remove configuration (optional)
    local config_dir="${HOME}/.config/macos-askpass"
    if [[ -d "$config_dir" ]]; then
        read -p "Remove configuration directory ${config_dir}? [y/N]: " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$config_dir"
            log_success "Configuration directory removed"
        fi
    fi
    
    # Remove keychain entry (optional)
    if security find-generic-password -a "$USER" -s "macos-askpass-sudo" >/dev/null 2>&1; then
        read -p "Remove stored password from keychain? [y/N]: " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            security delete-generic-password -a "$USER" -s "macos-askpass-sudo" 2>/dev/null || true
            log_success "Password removed from keychain"
        fi
    fi
    
    log_success "Uninstallation complete"
}

# Show usage
show_usage() {
    cat << EOF
macOS ASKPASS Installer v${VERSION}

USAGE:
    $0 [COMMAND]

COMMANDS:
    install (default)   Install askpass to ${INSTALL_DIR}
    uninstall          Remove askpass and optionally clean config
    update             Update to latest version
    help               Show this help

EXAMPLES:
    # Install askpass
    curl -fsSL ${REPO_URL}/raw/main/install.sh | bash
    
    # Install from local source
    ./install.sh
    
    # Uninstall
    ./install.sh uninstall

EOF
}

# Update function
update_askpass() {
    log_info "Updating macOS ASKPASS..."
    
    # Check if already installed
    local install_path="${INSTALL_DIR}/${SCRIPT_NAME}"
    if [[ ! -f "$install_path" ]]; then
        log_error "askpass is not installed. Run install first."
        exit 1
    fi
    
    # Get current version
    local current_version
    if current_version=$("$install_path" version 2>/dev/null | head -1 | grep -o 'v[0-9.]*'); then
        log_info "Current version: $current_version"
        log_info "Available version: v${VERSION}"
    fi
    
    # Proceed with installation (which will overwrite)
    install_askpass
    log_success "Update completed!"
}

# Main function
main() {
    case "${1:-install}" in
        "install"|"")
            echo "macOS ASKPASS Installer v${VERSION}"
            echo "================================="
            echo
            check_platform
            check_dependencies
            check_sudo
            install_askpass
            show_instructions
            ;;
        "uninstall")
            check_platform
            check_sudo
            uninstall_askpass
            ;;
        "update")
            echo "macOS ASKPASS Updater v${VERSION}"
            echo "================================"
            echo
            check_platform
            check_dependencies
            check_sudo
            update_askpass
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            log_error "Unknown command: $1"
            echo
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"