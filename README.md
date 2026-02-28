# AI-Bastion-Guardian 🛡️

### Windows Security for AI Agents

> **The outer wall.** AI-Bastion protects Linux. Guardian protects Windows.

AI-Bastion-Guardian secures the Windows side when running AI agents in WSL2 or as native Windows services. It provides firewall rules, outbound connection control, credential protection, and WSL2 hardening — all via PowerShell.

**Companion to:** [AI-Bastion](https://github.com/GravityZenAI/AI-Bastion) (Linux-side 8-layer defense)

---

## The Problem

When you run AI agents in WSL2:

1. **Port exposure** — WSL2 auto-forwards agent ports to Windows, potentially exposing them to your entire network
2. **API key theft** — `.env` files in WSL2 are readable from Windows Explorer (`\\wsl$\`)
3. **No egress control** — A compromised agent can HTTP to any IP with no restrictions
4. **Resource abuse** — A runaway agent in WSL2 can consume all host RAM/CPU

Guardian fixes all of these.

---

## Modules

| Module | What It Does | Status |
|--------|-------------|--------|
| **Network-Shield** | Windows Firewall rules blocking external access to agent ports (8000, 8888, 9999, 18789, 11434, 3000, 8080). Only allows localhost + WSL2 subnet. | ✅ v1.0 |
| **Egress-Proxy** | Outbound connection control. Agent processes (node, python, ollama) can only connect to whitelisted domains. | ✅ v1.0 |
| **Credential-Vault** | Moves API keys from `.env` files to Windows Credential Manager. Replaces values with `SECURED_BY_GUARDIAN`. | ✅ v1.0 |
| **WSL-Fence** | Detects exposed agent ports. Creates/hardens `.wslconfig` with resource limits and secure networking. | ✅ v1.0 |
| **Canary-Watch** | Windows-side canary token monitoring (ported from AI-Bastion Layer 2). | 📋 v1.2 |

---

## Quick Start

```powershell
# Clone
git clone https://github.com/GravityZenAI/AI-Bastion-Guardian.git
cd AI-Bastion-Guardian

# Preview what will be done (no changes)
.\guardian\Guardian.ps1 install -DryRun

# Install all modules (requires Administrator)
.\guardian\Guardian.ps1 install

# Check status
.\guardian\Guardian.ps1 status

# Install specific modules only
.\guardian\Guardian.ps1 install -Modules Network,WSL
```

> **Requires:** PowerShell 5.1+ and Administrator privileges for firewall rules.

---

## Requirements

* **OS:** Windows 10 21H2+ / Windows 11
* **PowerShell:** 5.1 or later (built into Windows)
* **Privileges:** Administrator (for firewall rules)
* **Optional:** WSL2 with Ubuntu (for full WSL-Fence functionality)
* **No external dependencies** — uses only built-in Windows APIs

---

## Repository Structure

```
AI-Bastion-Guardian/
├── guardian/
│   ├── Guardian.ps1                 # Main entry point
│   ├── modules/
│   │   ├── Network-Shield.psm1     # Windows Firewall for agent ports
│   │   ├── Egress-Proxy.psm1       # Outbound domain whitelist
│   │   ├── Credential-Vault.psm1   # API key → Credential Manager
│   │   ├── WSL-Fence.psm1          # WSL2 port exposure + .wslconfig
│   │   └── Canary-Watch.psm1       # Canary tokens (v1.2)
│   ├── config/
│   │   ├── guardian.json            # Main configuration
│   │   ├── allowed-domains.txt     # Egress whitelist
│   │   └── blocked-processes.txt   # Suspicious process patterns
│   └── lib/
│       └── Logger.ps1               # Shared logging utilities
│
├── scripts/
│   ├── Install-Guardian.ps1         # Quick install wrapper
│   ├── Uninstall-Guardian.ps1       # Clean removal
│   └── Status-Guardian.ps1          # Status check
│
├── tests/
│   └── Test-Guardian.ps1            # Verification suite
│
├── docs/
│   ├── THREAT-MODEL-WINDOWS.md      # Windows threat model
│   ├── WSL2-SECURITY.md             # WSL2 security guide
│   └── OWASP-ASI-MAPPING.md         # OWASP ASI coverage (Windows)
│
├── README.md                         # This file
├── LICENSE                           # Apache 2.0
└── .gitignore
```

---

## OWASP Agentic Security Coverage

Guardian maps to [OWASP ASI Top 10 (2026)](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/) from the Windows perimeter:

| ASI # | Risk | Guardian Module |
|-------|------|----------------|
| ASI01 | Agent Behavior Hijacking | Network-Shield |
| ASI02 | Prompt Injection | Network-Shield + Egress-Proxy |
| ASI03 | Tool Misuse | Egress-Proxy |
| ASI04 | Identity & Privilege Abuse | Credential-Vault |
| ASI05 | Inadequate Guardrails | WSL-Fence + Network-Shield |
| ASI06 | Information Disclosure | Egress-Proxy + Credential-Vault |
| ASI08 | DoS & Resource Exhaustion | WSL-Fence |
| ASI09 | Insecure Supply Chain | Network-Shield |

> **Combined with AI-Bastion: 10/10 ASI categories covered.** See [docs/OWASP-ASI-MAPPING.md](docs/OWASP-ASI-MAPPING.md) for the full mapping.

---

## Configuration

### Agent Ports

Edit `guardian/config/guardian.json` to add or remove agent ports:

```json
{
    "agent_ports": [
        { "port": 8000,  "name": "FastAPI/Uvicorn" },
        { "port": 18789, "name": "OpenClaw Default" },
        { "port": 11434, "name": "Ollama API" }
    ]
}
```

### Egress Whitelist

Edit `guardian/config/allowed-domains.txt` to control which domains agents can reach:

```
# AI Provider APIs
api.anthropic.com
api.openai.com

# Your custom domains
your-api.example.com
```

---

## Defense-in-Depth

```
┌─────────────────────────────────────────────────────────┐
│  Windows Host                                            │
│  ├── Network-Shield (inbound firewall)                   │
│  ├── Egress-Proxy (outbound whitelist)                   │
│  ├── Credential-Vault (key encryption)                   │
│  ├── WSL-Fence (port detection + .wslconfig)             │
│  │                                                       │
│  └── WSL2 (Hyper-V VM)                                   │
│      └── AI-Bastion Layers 0-7                           │
│          ├── nftables, DNS-over-TLS                      │
│          ├── Canary tokens                               │
│          ├── Anti-prompt injection                        │
│          ├── Process/network monitoring                   │
│          ├── SHA-256 integrity                            │
│          └── SOAR auto-response                          │
└─────────────────────────────────────────────────────────┘
```

---

## Uninstall

```powershell
# Remove all Guardian protections
.\guardian\Guardian.ps1 uninstall

# This removes:
# - All Guardian_* Windows Firewall rules
# - All Guardian_* entries in Credential Manager
# Does NOT remove .wslconfig changes (manual)
```

---

## Roadmap

| Version | Features | Timeline |
|---------|----------|----------|
| **v1.0** | Network-Shield + WSL-Fence + Egress-Proxy + Credential-Vault | ✅ Done |
| **v1.1** | Status dashboard + log viewer | 1 weekend |
| **v1.2** | Canary-Watch (Windows-side canary tokens) | 1 weekend |
| **v2.0** | WFP deep integration (per-process egress at kernel level) | 2-3 weeks |
| **v2.1** | Windows Event Log integration | 1 week |

> For the full roadmap including v3.0 plans (compiled binary, Windows service, GUI), see [ROADMAP.md](ROADMAP.md).

---

## Companion Projects

| Project | Purpose |
|---------|---------|
| [AI-Bastion](https://github.com/GravityZenAI/AI-Bastion) | 8-layer Linux infrastructure defense |
| [rust-ai-governance-pack](https://github.com/GravityZenAI/rust-ai-governance-pack) | AI code governance for Rust |

---

## License

Apache License 2.0 — See [LICENSE](LICENSE) for details.

No external dependencies. Guardian uses only built-in Windows APIs (Windows Firewall, Credential Manager, netstat, WSL CLI).

---

## Credits

Created by **[GravityZen AI](https://github.com/GravityZenAI)** — Trinidad Operativa (Cerebro + Manos + Jefe)

*"The fortress protects the inside. The wall protects the fortress."*
