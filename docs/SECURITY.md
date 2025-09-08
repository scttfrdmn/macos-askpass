# Security Guide for macOS ASKPASS

This document outlines the security considerations, best practices, and threat model for macOS ASKPASS.

## 🛡️ Security Model

### Threat Model

macOS ASKPASS is designed to protect against:

- ✅ **Password exposure in logs** - No passwords written to files or logs
- ✅ **Credential theft from storage** - Uses macOS Keychain security
- ✅ **Process inspection** - Minimal password lifetime in memory  
- ✅ **Unauthorized access** - Proper file permissions and access controls
- ✅ **Configuration tampering** - Validates sources and permissions

### Security Boundaries

- **In Scope**: Secure password storage and retrieval for legitimate sudo operations
- **Out of Scope**: Protection against root-level attacks or kernel exploitation
- **Assumptions**: Legitimate user account with sudo privileges on trusted system

## 🔐 Password Security

### Storage Security

#### 1. **macOS Keychain Integration**
```bash
# Passwords stored with restricted access
security add-generic-password \
    -a "$USER" \
    -s "macos-askpass-sudo" \
    -T "$(which askpass)" \     # Only askpass can access
    -T "/usr/bin/sudo" \        # Only sudo can access
    -w "$password"
```

**Security Features:**
- Access restricted to specific applications
- Encrypted storage using macOS security framework
- User authentication required for first access
- Automatic locking when system is locked

#### 2. **Environment Variable Handling**
```bash
# Variables cleared after use
unset SUDO_PASSWORD CI_SUDO_PASSWORD

# Debug mode controls sensitive logging
if [[ -n "${ASKPASS_DEBUG:-}" ]]; then
    echo "DEBUG: Password source used" >&2  # Never log actual password
fi
```

**Security Features:**
- Passwords not written to disk
- Cleared from environment after use
- Debug mode never logs actual passwords
- Process environment isolated

### Password Priority System

1. **`CI_SUDO_PASSWORD`** - CI/CD environments (ephemeral)
2. **`SUDO_PASSWORD`** - Local development (temporary)
3. **macOS Keychain** - Persistent secure storage
4. **Interactive prompt** - Direct user input

**Security Rationale:**
- CI/CD passwords are ephemeral and scoped to build
- Local environment variables are session-limited
- Keychain provides persistent secure storage
- Interactive prompts ensure user awareness

## 🔒 Access Controls

### File Permissions

```bash
# Configuration files (if used)
chmod 600 ~/.config/macos-askpass/config    # Owner read/write only

# Script permissions
chmod 755 /usr/local/bin/askpass            # World executable, owner writable
```

### Keychain Access Control

```bash
# View access control list
security dump-keychain -a | grep macos-askpass-sudo

# Applications with access:
# - /usr/local/bin/askpass
# - /usr/bin/sudo
```

### Process Security

- **No privilege escalation** - askpass runs as user, not root
- **Minimal attack surface** - Pure bash implementation
- **Process isolation** - No network access or external dependencies

## 🚨 Threat Analysis

### High-Risk Scenarios

#### 1. **Credential Theft**
**Threat**: Attacker gains access to stored passwords
**Mitigations**:
- macOS Keychain encryption at rest
- Access control lists restrict application access
- No plaintext password files
- Environment variables cleared after use

#### 2. **Process Memory Inspection**
**Threat**: Attacker inspects process memory for passwords
**Mitigations**:
- Minimal password lifetime in memory
- Bash variable scope limits exposure
- Process runs as user (not root)

#### 3. **Configuration Tampering**
**Threat**: Attacker modifies askpass configuration
**Mitigations**:
- Script integrity protected by file system permissions
- Configuration files use restrictive permissions (600)
- Input validation on all external data

#### 4. **Supply Chain Attack**
**Threat**: Compromised askpass installation
**Mitigations**:
- Installation from trusted sources (GitHub releases)
- Script integrity verification possible
- Minimal dependencies (bash + macOS built-ins)

### Medium-Risk Scenarios

#### 1. **Log File Exposure**
**Threat**: Passwords exposed in system or application logs
**Mitigations**:
- No password logging in askpass
- Debug mode logs events, not credentials
- CI/CD systems should use masked variables

#### 2. **Environment Variable Leakage**
**Threat**: Password environment variables visible to other processes
**Mitigations**:
- Variables cleared after use
- Process isolation limits visibility
- CI/CD systems provide secret masking

### Low-Risk Scenarios

#### 1. **Network Interception**
**Risk Level**: Low (no network communication)
**Mitigations**: askpass operates locally only

#### 2. **Social Engineering**
**Risk Level**: Low (technical solution)
**Mitigations**: User education and awareness

## 🔧 Security Configuration

### Hardening Recommendations

#### 1. **System Level**
```bash
# Ensure secure file permissions
find /usr/local/bin/askpass -type f -exec chmod 755 {} \;

# Verify no world-writable configuration
find ~/.config/macos-askpass -type f -perm +002 -exec chmod 600 {} \;

# Check keychain access
security dump-keychain -a | grep askpass
```

#### 2. **CI/CD Level**
```yaml
# GitHub Actions security
- name: Configure ASKPASS
  env:
    CI_SUDO_PASSWORD: ${{ secrets.MACOS_SUDO_PASSWORD }}
  run: |
    # Verify secret is masked in logs
    echo "Password configured: ${CI_SUDO_PASSWORD:+YES}" # Shows YES, not password
    
    # Set ASKPASS with proper quoting
    export SUDO_ASKPASS="$(which askpass)"
    
    # Verify functionality
    askpass test
```

#### 3. **Local Development**
```bash
# Use keychain for persistent storage
askpass store

# Avoid environment variables in persistent shell configuration
# BAD: echo 'export SUDO_PASSWORD="..."' >> ~/.bashrc
# GOOD: Use keychain or session-only variables
```

### Security Monitoring

#### 1. **Audit Keychain Access**
```bash
# List keychain entries
security find-generic-password -a "$USER" -s "macos-askpass-sudo"

# Check access history (if logging enabled)
log show --predicate 'process == "Security"' --last 1h | grep askpass
```

#### 2. **Monitor Configuration Changes**
```bash
# Watch configuration directory
fswatch ~/.config/macos-askpass/ | while read event; do
    echo "Config changed: $event"
    # Add alerting logic here
done
```

## 🚨 Incident Response

### Credential Compromise

#### 1. **Immediate Actions**
```bash
# Remove compromised password from keychain
security delete-generic-password -a "$USER" -s "macos-askpass-sudo"

# Clear environment variables
unset SUDO_PASSWORD CI_SUDO_PASSWORD

# Remove configuration files
rm -rf ~/.config/macos-askpass/
```

#### 2. **System Hardening**
```bash
# Change user password
passwd

# Review sudo access logs
last | grep sudo
log show --predicate 'process == "sudo"' --last 24h

# Check for unauthorized modifications
find /usr/local/bin/askpass -newer /tmp/reference_file
```

#### 3. **Recovery**
```bash
# Reinstall from trusted source
curl -fsSL https://raw.githubusercontent.com/scttfrdmn/macos-askpass/main/install.sh | bash

# Reconfigure with new credentials
askpass setup

# Test functionality
askpass test
```

### CI/CD Compromise

#### 1. **Immediate Actions**
- Rotate secrets in CI/CD system
- Review build logs for credential exposure
- Audit recent builds and deployments

#### 2. **Long-term Hardening**
- Implement secret rotation schedule
- Add security scanning to CI/CD pipeline
- Review access controls and permissions

## 📋 Security Checklist

### Installation Security
- [ ] Install from official source (GitHub releases)
- [ ] Verify script permissions (755 for executable)
- [ ] Check configuration directory permissions (700)
- [ ] Validate no world-writable files

### Configuration Security
- [ ] Use keychain for persistent passwords
- [ ] Avoid plaintext password files
- [ ] Set restrictive file permissions (600)
- [ ] Clear environment variables after use

### Operational Security
- [ ] Regular password rotation
- [ ] Monitor keychain access
- [ ] Review CI/CD logs for exposure
- [ ] Test backup and recovery procedures

### Development Security
- [ ] Never commit passwords to version control
- [ ] Use secrets management in CI/CD
- [ ] Test in isolated environments
- [ ] Regular security updates

## 🔗 Security Resources

### Related Security Tools
- **Keychain Access.app** - GUI for keychain management
- **security(1)** - Command-line keychain utilities
- **Console.app** - System log monitoring
- **Activity Monitor.app** - Process monitoring

### Security References
- [Apple Security Guide](https://support.apple.com/guide/security/)
- [macOS Security Compliance Project](https://github.com/usnistgov/macos_security)
- [OWASP Secure Coding Practices](https://owasp.org/www-project-secure-coding-practices-quick-reference-guide/)

---

**Remember**: Security is a process, not a destination. Regularly review and update your security practices as threats evolve.