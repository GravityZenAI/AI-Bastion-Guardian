# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in AI-Bastion-Guardian, please report it responsibly.

### How to Report

1. **DO NOT** open a public GitHub issue for security vulnerabilities
2. Use [GitHub Security Advisories](https://github.com/GravityZenAI/AI-Bastion-Guardian/security/advisories/new) to report privately
3. Or email: gravityzenai@protonmail.com

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response Timeline

- **Acknowledgment:** Within 48 hours
- **Assessment:** Within 1 week
- **Fix:** Depends on severity (critical: 72h, high: 1 week, medium: 2 weeks)

## Scope

The following are in scope for security reports:

- Guardian PowerShell modules (Network-Shield, Egress-Proxy, Credential-Vault, WSL-Fence)
- Configuration files and their handling
- Credential storage and retrieval
- Firewall rule creation and management
- Any bypass of Guardian protections

## Out of Scope

- Vulnerabilities in Windows itself or WSL2
- Issues requiring physical access to the machine
- Social engineering attacks
- Denial of service against the Guardian scripts themselves

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.0.x   | ✅        |
| < 1.0   | ❌        |
