# macOS ASKPASS 🔐

> Secure sudo authentication for macOS CI/CD and automation

[![macOS](https://img.shields.io/badge/macOS-Compatible-blue.svg)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0.0-green.svg)](https://github.com/scttfrdmn/macos-askpass/releases)

## 🎯 Problem Solved

Ever tried to run `sudo` commands in macOS CI/CD pipelines and hit this error?

```
sudo: no tty present and no askpass program specified
```

**macOS ASKPASS** solves this by providing secure, automated sudo authentication for:
- ✅ **GitHub Actions** workflows
- ✅ **Jenkins** pipelines  
- ✅ **Local development** automation
- ✅ **Integration testing** requiring root privileges
- ✅ **System configuration** scripts

## 🚀 Quick Start

### Installation

#### Option 1: One-line install (recommended)
```bash
curl -fsSL https://raw.githubusercontent.com/scttfrdmn/macos-askpass/main/install.sh | bash
```

#### Option 2: Homebrew (coming soon)
```bash
brew tap scttfrdmn/tap
brew install macos-askpass
```

#### Option 3: Manual install
```bash
git clone https://github.com/scttfrdmn/macos-askpass.git
cd macos-askpass
make install
```

### Setup

```bash
# Interactive setup (recommended for first-time users)
askpass setup

# Test functionality
askpass test

# Show configuration
askpass config
```

### Usage

#### Local Development

**GUI Mode (Interactive)**
```bash
# Set up environment
export SUDO_ASKPASS=$(which askpass)

# Use with any sudo command - shows native macOS dialog
sudo -A systemsetup -getremotelogin  # 🖥️ GUI password dialog appears
sudo -A make install-deps             # 🖥️ GUI password dialog appears
```

**CLI Mode (Automation)**
```bash
# Store password in keychain (one-time setup)
askpass store

# Or use environment variable
export SUDO_PASSWORD="your_password"
export SUDO_ASKPASS=$(which askpass)

# Use with any sudo command - no dialogs
sudo -A ./integration-tests.sh       # ⚡ Automated, no prompts
sudo -A make install-system-deps     # ⚡ Automated, no prompts
```

**Force CLI Mode**
```bash
# Disable GUI dialogs even in interactive environments
export ASKPASS_FORCE_CLI=1
export SUDO_ASKPASS=$(which askpass)
sudo -A echo "Always uses stored credentials" # 🚫 No GUI dialog
```

#### CI/CD (GitHub Actions)
```yaml
- name: Run integration tests
  env:
    CI_SUDO_PASSWORD: ${{ secrets.MACOS_SUDO_PASSWORD }}
  run: |
    export SUDO_ASKPASS=$(which askpass)
    sudo -A make integration-test
```

## 🔧 Features

### 🔐 **Multi-Source Authentication**
Secure password retrieval with intelligent priority system:

1. **`CI_SUDO_PASSWORD`** - CI/CD environment variable (highest priority)
2. **`SUDO_PASSWORD`** - Local development environment variable
3. **macOS Keychain** - Secure local storage
4. **GUI Dialog** - Native macOS password dialog (interactive environments)
5. **Terminal prompt** - Fallback for TTY environments

### 🛡️ **Security First**
- ✅ No permanent password storage in files
- ✅ macOS Keychain integration with access controls
- ✅ Environment variable clearing after use  
- ✅ Input validation and sanitization
- ✅ Secure file permissions (600)

### 🎯 **Developer Experience**
- ✅ **Smart Mode Detection**: Automatically chooses GUI or CLI based on environment
- ✅ **Zero Configuration**: Works out of the box with environment variables
- ✅ **Interactive Setup**: Guided configuration wizard
- ✅ **Native GUI**: macOS password dialogs for interactive use
- ✅ **CLI Automation**: Perfect for scripts and CI/CD
- ✅ **Comprehensive Help**: Built-in documentation and examples
- ✅ **Debug Mode**: Detailed logging for troubleshooting

### 🚀 **CI/CD Ready**
- ✅ GitHub Actions integration
- ✅ Jenkins support
- ✅ GitLab CI compatibility
- ✅ Generic CI/CD system support

## 📖 Documentation

### Commands

| Command | Description |
|---------|-------------|
| `askpass` | Output password (ASKPASS mode) |
| `askpass setup` | Interactive configuration wizard |
| `askpass test` | Test functionality |
| `askpass config` | Show current configuration |
| `askpass store` | Store password in keychain |
| `askpass remove` | Remove stored password |
| `askpass version` | Show version information |
| `askpass help` | Show help message |

### Environment Variables

| Variable | Purpose | Priority |
|----------|---------|----------|
| `CI_SUDO_PASSWORD` | CI/CD password | 1 (highest) |
| `SUDO_PASSWORD` | Local development password | 2 |
| `SUDO_ASKPASS` | Path to askpass program | Required |
| `ASKPASS_FORCE_CLI` | Disable GUI dialogs (set to 1) | Optional |
| `ASKPASS_DEBUG` | Enable debug logging | Optional |

## 🏗️ Integration Examples

### GitHub Actions

```yaml
name: macOS Integration Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Install askpass
      run: |
        curl -fsSL https://raw.githubusercontent.com/scttfrdmn/macos-askpass/main/install.sh | bash
    
    - name: Run integration tests
      env:
        CI_SUDO_PASSWORD: ${{ secrets.MACOS_SUDO_PASSWORD }}
      run: |
        export SUDO_ASKPASS=$(which askpass)
        sudo -A make integration-test
```

### Jenkins Pipeline

```groovy
pipeline {
    agent { label 'macos' }
    
    environment {
        CI_SUDO_PASSWORD = credentials('macos-sudo-password')
        SUDO_ASKPASS = '/usr/local/bin/askpass'
    }
    
    stages {
        stage('Test') {
            steps {
                sh 'sudo -A make integration-test'
            }
        }
    }
}
```

### Local Development

```bash
# One-time setup
askpass setup

# Daily usage
export SUDO_ASKPASS=$(which askpass)
sudo -A ./run-tests.sh
sudo -A make install-system-deps
```

### Makefile Integration

```makefile
# Test target that works in both local and CI environments
test-integration:
	@if [ -z "$$SUDO_ASKPASS" ]; then \
		export SUDO_ASKPASS=$$(which askpass); \
	fi
	sudo -A ./integration-tests.sh

setup-askpass:
	@command -v askpass >/dev/null || { \
		echo "Installing askpass..."; \
		curl -fsSL https://raw.githubusercontent.com/scttfrdmn/macos-askpass/main/install.sh | bash; \
	}
	askpass setup
```

## 🔍 Troubleshooting

### Common Issues

#### ❌ `sudo: no askpass program specified`
```bash
# Solution: Set SUDO_ASKPASS environment variable
export SUDO_ASKPASS=$(which askpass)
```

#### ❌ `askpass: command not found`
```bash
# Solution: Install askpass
curl -fsSL https://raw.githubusercontent.com/scttfrdmn/macos-askpass/main/install.sh | bash
```

#### ❌ `Failed to retrieve password from any source`
```bash
# Solution: Configure password source
askpass setup  # Interactive setup

# OR set environment variable
export SUDO_PASSWORD="your_password"

# OR store in keychain
askpass store
```

### Debug Mode

Enable detailed logging:
```bash
export ASKPASS_DEBUG=1
askpass test
```

Sample debug output:
```
ASKPASS DEBUG: Called by sudo (PID: 12345)
ASKPASS DEBUG: User: username
ASKPASS DEBUG: Attempting password retrieval...
ASKPASS DEBUG: Using keychain password source
✅ Password retrieval successful
```

## 🧪 Testing

### Local Testing
```bash
# Test basic functionality
make test

# Test with environment variable
SUDO_PASSWORD="test" askpass test

# Test CI/CD mode  
make test-ci TEST_PASSWORD="test"
```

### Integration Testing
```bash
# Test with real sudo command
export SUDO_ASKPASS=$(which askpass)
sudo -A echo "ASKPASS working!"

# Test system integration
sudo -A systemsetup -getremotelogin
```

## 🔧 Development

### Building from Source
```bash
git clone https://github.com/scttfrdmn/macos-askpass.git
cd macos-askpass

# Install locally
make install-local

# Run tests
make test

# Development cycle
make dev
```

### Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly: `make check`
5. Submit a pull request

## 📋 Requirements

- **macOS** 10.14+ (Mojave or later)
- **Bash** 4.0+ (included with macOS)
- **sudo** privileges
- **curl** (for installation)

## 🤝 Use Cases

### Real-World Examples

**Network Testing**
```bash
sudo -A pfctl -sr                    # Check firewall rules
sudo -A ifconfig bridge100 create   # Create network bridge
```

**System Configuration**  
```bash
sudo -A systemsetup -setremotelogin on
sudo -A launchctl load /Library/LaunchDaemons/service.plist
```

**Package Management**
```bash
sudo -A make install-deps
sudo -A installer -pkg package.pkg -target /
```

**Integration Testing**
```bash
sudo -A ./test-network-config.sh
sudo -A ./test-system-integration.sh
```

## 🆚 Alternatives Comparison

| Feature | macOS ASKPASS | ssh-askpass | Manual Scripts |
|---------|---------------|-------------|----------------|
| **CI/CD Ready** | ✅ Purpose-built | ❌ GUI-focused | ⚠️ Custom implementation |
| **Security** | ✅ Multi-source + Keychain | ⚠️ Basic | ❌ Often insecure |
| **Documentation** | ✅ Comprehensive | ❌ Minimal | ❌ None |
| **Maintenance** | ✅ Active | ❌ Stale | ❌ Per-project |
| **macOS Integration** | ✅ Native | ✅ Native | ⚠️ Varies |

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

Inspired by the need for secure macOS automation in CI/CD pipelines. Built for the developer community that runs into sudo authentication challenges in automated environments.

## 🔗 Links

- **GitHub**: https://github.com/scttfrdmn/macos-askpass
- **Issues**: https://github.com/scttfrdmn/macos-askpass/issues
- **Releases**: https://github.com/scttfrdmn/macos-askpass/releases

---

**Made with ❤️ for the macOS developer community**