# Threat Model: Windows + AI Agents

## Context

When AI agents run in WSL2 or as native Windows services, the Windows host becomes part of the attack surface. AI-Bastion secures the Linux side. **AI-Bastion-Guardian** secures the Windows side.

---

## Threats Addressed

### T1: WSL2 Port Exposure

**Risk:** WSL2 auto-forwards listening ports to the Windows host. If the agent binds to `0.0.0.0`, those ports become accessible from the local network.

**Impact:** Any device on the same network can send requests to your AI agent — including prompt injection attacks.

**Example:** OpenClaw gateway starts on port 18789. WSL2 forwards it. Your phone on the same WiFi can now talk to your agent.

**Guardian Defense:** Network-Shield creates Windows Firewall rules that block inbound traffic to agent ports from all IPs except localhost and WSL2 subnet.

---

### T2: API Key Theft via Windows

**Risk:** WSL2 file systems are accessible from Windows Explorer (`\\wsl$\Ubuntu\home\...`). Any Windows malware or other user can read `.env` files containing API keys.

**Impact:** Stolen API keys allow attackers to use your accounts (Anthropic, OpenAI, etc.) at your expense, or access your data.

**Guardian Defense:** Credential-Vault moves sensitive keys from `.env` files to Windows Credential Manager (encrypted, per-user).

---

### T3: Uncontrolled Egress

**Risk:** A compromised agent can make outbound HTTP requests to any IP address. Windows has no default egress control for specific processes.

**Impact:** Data exfiltration, beacon to C2 server, download malware payloads.

**Guardian Defense:** Egress-Proxy creates per-process outbound firewall rules that only allow connections to whitelisted domains.

---

### T4: Resource Exhaustion

**Risk:** A compromised or malfunctioning agent in WSL2 can consume all available RAM and CPU, affecting the entire Windows host.

**Impact:** System freeze, crash, denial of service.

**Guardian Defense:** WSL-Fence configures `.wslconfig` with memory and CPU limits.

---

### T5: Network-Level Attacks

**Risk:** An attacker on the same network who discovers an exposed agent port can:
- Send prompt injection payloads
- Access agent memory/history
- Trigger tool use (file operations, code execution)

**Impact:** Full compromise of the agent and potentially the host.

**Guardian Defense:** Network-Shield + WSL-Fence ensure agent ports are only accessible from localhost.

---

## Defense-in-Depth Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  INTERNET                                                    │
│  ▼                                                           │
│  [Windows Firewall] ← Guardian Network-Shield                │
│  ▼                                                           │
│  [Windows Host]                                              │
│  ├── Guardian Egress-Proxy (outbound control)                │
│  ├── Guardian Credential-Vault (key protection)              │
│  ├── Guardian WSL-Fence (port exposure detection)            │
│  │                                                           │
│  └── [WSL2 Hyper-V VM]                                      │
│      ├── AI-Bastion Layer 0-7                                │
│      ├── nftables (Layer 1)                                  │
│      ├── Canary tokens (Layer 2)                             │
│      ├── Anti-injection (Layer 3)                            │
│      ├── Monitoring (Layer 4)                                │
│      └── SOAR Response (Layer 6)                             │
│                                                              │
│  ▼                                                           │
│  [AI Agent] ← Protected by both Guardian + AI-Bastion        │
└─────────────────────────────────────────────────────────────┘
```

---

## Threats NOT Addressed

Guardian does NOT protect against:

- **Physical access attacks** — If someone has physical access to your machine, Guardian can be bypassed
- **Kernel exploits** — A WSL2 kernel exploit could bypass Hyper-V isolation
- **Windows malware with admin privileges** — Admin malware can disable firewall rules
- **Social engineering** — Guardian protects infrastructure, not people
- **Supply chain attacks on Windows packages** — Guardian doesn't verify Windows software integrity

For these threats, follow standard Windows security practices (BitLocker, Windows Defender, regular updates).
