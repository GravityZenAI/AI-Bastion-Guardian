# ROADMAP — AI-Bastion-Guardian 🛡️

> Future improvements and planned features.
> Updated: February 28, 2026

---

## Current Version: v1.0.0

✅ Network-Shield (Windows Firewall for agent ports)
✅ Egress-Proxy (outbound domain whitelist)
✅ Credential-Vault (API keys → Windows Credential Manager)
✅ WSL-Fence (port exposure detection + .wslconfig)
✅ OWASP ASI mapping (Windows perimeter)
✅ Test suite

---

## Short Term (v1.1 — v1.2)

### v1.1 — Status Dashboard & Logging
- [ ] Enhanced status output with color-coded risk levels
- [ ] Log viewer: `.\Guardian.ps1 logs --last 50`
- [ ] Log rotation (archive logs older than 30 days)
- [ ] Export status report as HTML file

### v1.2 — Canary-Watch Module
- [ ] Port canary token system from AI-Bastion Layer 2 to Windows
- [ ] Create honeypot .env files that alert on access
- [ ] Windows File System auditing for canary directories
- [ ] Windows Event Log integration for canary alerts

---

## Medium Term (v2.0 — v2.1)

### v2.0 — WFP Deep Integration
- [ ] Replace firewall rules with Windows Filtering Platform (WFP) callout drivers
- [ ] Per-process egress control at kernel level (not just firewall rules)
- [ ] Real-time connection logging per agent process
- [ ] Why: WFP operates at a lower level than Windows Firewall rules and cannot be bypassed by user-mode processes

### v2.1 — Windows Event Log Integration
- [ ] Write all Guardian events to Windows Event Log
- [ ] Custom event source "AI-Bastion-Guardian"
- [ ] Severity levels mapped to Windows event types
- [ ] Compatible with SIEM tools (Splunk, Sentinel, Elastic)

---

## Long Term (v3.0)

### Compiled Binary (Rust or Go)
- [ ] Rewrite Guardian modules as a compiled Windows service
- [ ] Single .exe installer (no PowerShell dependency)
- [ ] Signed binary with code signing certificate
- [ ] Cannot be modified by compromised agent or script
- [ ] Why: PowerShell scripts can be edited by any admin process. A signed .exe provides tamper resistance.

### Windows Service Mode
- [ ] Run Guardian as a Windows background service
- [ ] Auto-start on boot
- [ ] System tray icon with status indicator
- [ ] Auto-update domain whitelist IPs periodically

### Active Response
- [ ] Detect and auto-block suspicious outbound connections in real-time
- [ ] Kill agent process if it attempts connection to non-whitelisted IP
- [ ] Alert via Windows notification + optional webhook (Slack, Discord, Telegram)

### GUI Configuration
- [ ] Windows Settings-style GUI for managing Guardian
- [ ] Visual port exposure map
- [ ] One-click enable/disable modules
- [ ] Credential manager browser

---

## Ecosystem

| Project | Status | Purpose |
|---------|--------|---------|
| [AI-Bastion](https://github.com/GravityZenAI/AI-Bastion) | ✅ v1.0 | Linux infrastructure defense |
| [AI-Bastion-Guardian](https://github.com/GravityZenAI/AI-Bastion-Guardian) | ✅ v1.0 | Windows perimeter defense |
| [rust-ai-governance-pack](https://github.com/GravityZenAI/rust-ai-governance-pack) | ✅ v1.0 | AI code governance for Rust |

---

## Contributing

Have ideas? Open an issue.

Priority is given to contributions that:
1. Fix security vulnerabilities
2. Improve WFP integration
3. Add real-time monitoring capabilities
4. Port modules to compiled languages
