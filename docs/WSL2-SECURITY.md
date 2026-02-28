# WSL2 Security Guide

## How WSL2 Networking Works

WSL2 runs inside a lightweight Hyper-V virtual machine. This provides stronger isolation than WSL1 (which shared the Windows kernel), but introduces networking complexity.

### NAT Mode (Default)

In the default NAT mode:

1. WSL2 gets its own virtual network adapter with a 172.x.x.x address
2. Windows creates a virtual switch that bridges WSL2 to the host
3. **Ports that WSL2 apps listen on are automatically forwarded to the Windows host**
4. By default, these forwarded ports listen on `localhost` (127.0.0.1)

This means: if your AI agent in WSL2 listens on port 18789, Windows also starts listening on 127.0.0.1:18789.

### The Exposure Problem

If the agent binds to `0.0.0.0` instead of `127.0.0.1`:
- WSL2 forwards the port to Windows
- Windows may expose it on ALL interfaces (0.0.0.0)
- Any device on your network can now reach your agent

This is the **#1 security risk** for AI agents on WSL2.

---

## .wslconfig Security Settings

The file `%USERPROFILE%\.wslconfig` controls WSL2 behavior globally.

### Recommended Settings

```ini
[wsl2]
# Keep port forwarding to localhost only
localhostForwarding=true

# Limit resources (prevents DoS from compromised agents)
memory=16GB
processors=8
swap=4GB

[experimental]
# Windows 11 22H2+: Use mirrored networking for better control
# networkingMode=mirrored

# Auto-reclaim unused memory
autoMemoryReclaim=gradual
```

### After Changing .wslconfig

```powershell
# Restart WSL2 for changes to take effect
wsl --shutdown
# Then start your distro again
wsl
```

---

## Mirrored Networking Mode (Windows 11)

Windows 11 22H2+ supports `networkingMode=mirrored`, which:

- Makes WSL2 share the Windows network stack
- Gives WSL2 the same IP as Windows (no more 172.x.x.x)
- Simplifies firewall rules
- **Better compatibility with Guardian's Network-Shield**

To enable:

```ini
[experimental]
networkingMode=mirrored
```

> **Note:** Mirrored mode may cause issues with some VPN software. Test before committing.

---

## File System Access

### Windows → WSL2

Windows can access WSL2 files via `\\wsl$\<distro>\`:
```
\\wsl$\Ubuntu\home\user\.env        ← Your API keys are here
\\wsl$\Ubuntu\home\user\.openclaw\  ← Agent config
```

**This is a security risk.** Any Windows process (or Windows user) can read these files.

**Mitigation:** Use Guardian's Credential-Vault to move sensitive keys to Windows Credential Manager.

### WSL2 → Windows

WSL2 can access Windows drives via `/mnt/c/`, `/mnt/d/`, etc.:
```
/mnt/c/Users/username/Documents/
```

**Mitigation:** AI-Bastion Layer 7 (system hardening) restricts file permissions inside WSL2.

---

## Recommended Security Stack for WSL2 Users

| Layer | Tool | Purpose |
|-------|------|---------|
| Windows perimeter | **AI-Bastion-Guardian** | Firewall, egress, credentials, WSL config |
| WSL2 infrastructure | **AI-Bastion** | 8-layer defense inside the VM |
| Agent runtime | **SecureClaw** | Behavioral baselines, kill switch (OpenClaw only) |
| Code governance | **rust-ai-governance-pack** | Code quality gates (Rust projects) |

---

## Quick Security Check

Run this from PowerShell to check your WSL2 security posture:

```powershell
# 1. Check if any agent ports are exposed
$ports = @(8000, 8888, 9999, 18789, 11434)
foreach ($p in $ports) {
    $exposed = netstat -an | Select-String "0\.0\.0\.0:$p\s"
    if ($exposed) { Write-Host "WARNING: Port $p exposed!" -ForegroundColor Red }
}

# 2. Check .wslconfig exists
if (Test-Path "$env:USERPROFILE\.wslconfig") {
    Write-Host ".wslconfig exists" -ForegroundColor Green
} else {
    Write-Host ".wslconfig missing — run Guardian to create" -ForegroundColor Yellow
}

# 3. Check for .env files accessible from Windows
$envFiles = Get-ChildItem "\\wsl$\Ubuntu\home\*\.env" -ErrorAction SilentlyContinue
if ($envFiles) {
    Write-Host "Found $($envFiles.Count) .env file(s) accessible from Windows" -ForegroundColor Yellow
}
```
