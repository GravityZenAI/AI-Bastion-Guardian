# Changelog

All notable changes to AI-Bastion-Guardian will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-28

### Added
- Network-Shield module: Windows Firewall rules for agent ports
- Egress-Proxy module: Outbound domain whitelist for agent processes
- Credential-Vault module: API key protection via Windows Credential Manager
- WSL-Fence module: WSL2 port exposure detection + .wslconfig hardening
- Canary-Watch module: Placeholder for v1.2
- Guardian.ps1 main entry point with install/uninstall/status/help
- Logger.ps1 shared logging utilities
- guardian.json configuration file
- allowed-domains.txt egress whitelist
- blocked-processes.txt suspicious process patterns
- Test-Guardian.ps1 verification suite
- Install/Uninstall/Status wrapper scripts
- Windows threat model documentation
- WSL2 security guide
- OWASP ASI mapping (Windows-side)
- ROADMAP.md with v2.0 and v3.0 plans
