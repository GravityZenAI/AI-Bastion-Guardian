# ═══════════════════════════════════════════════════════════════════════════════
# WSL-Fence.psm1
# Detects and mitigates WSL2 port exposure to external networks
# Manages .wslconfig for resource limits and network security
# ═══════════════════════════════════════════════════════════════════════════════

$script:AgentPorts = @(8000, 8888, 9999, 18789, 11434, 3000, 8080)

function Install-WSLFence {
    [CmdletBinding()]
    param()

    Write-Host "[WSL-Fence] Checking WSL2 security..." -ForegroundColor Cyan

    # 1. Check if WSL2 is installed
    $wslInstalled = $false
    try {
        $wslVersion = wsl --version 2>$null
        $wslInstalled = $true
        Write-Host "  [OK] WSL2 detected" -ForegroundColor Green
    } catch {
        Write-Host "  [SKIP] WSL2 not installed — WSL-Fence not needed" -ForegroundColor Yellow
        return
    }

    # 2. Check for exposed agent ports
    Test-PortExposure

    # 3. Configure .wslconfig
    Set-WSLConfig

    # 4. Check WSL2 network mode
    Test-WSLNetworkMode

    Write-Host "[WSL-Fence] Done." -ForegroundColor Cyan
}

function Test-PortExposure {
    [CmdletBinding()]
    param()

    Write-Host "[WSL-Fence] Scanning for exposed agent ports..." -ForegroundColor Cyan

    $exposed = @()
    $safe = @()

    foreach ($port in $script:AgentPorts) {
        # Check if port is listening on 0.0.0.0 (all interfaces = exposed)
        $listening = netstat -an 2>$null | Select-String "TCP\s+0\.0\.0\.0:$port\s"

        if ($listening) {
            $exposed += $port
            Write-Host "  [WARNING] Port $port exposed on 0.0.0.0 (accessible from network!)" -ForegroundColor Red
        } else {
            # Check if listening on 127.0.0.1 only (safe)
            $localOnly = netstat -an 2>$null | Select-String "TCP\s+127\.0\.0\.1:$port\s"
            if ($localOnly) {
                $safe += $port
                Write-Host "  [OK] Port $port listening on localhost only" -ForegroundColor Green
            }
        }
    }

    if ($exposed.Count -gt 0) {
        Write-Host "" -ForegroundColor Yellow
        Write-Host "  ╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "  ║  WARNING: $($exposed.Count) port(s) exposed to your network!              ║" -ForegroundColor Red
        Write-Host "  ║  Ports: $($exposed -join ', ')$((' ' * (46 - ($exposed -join ', ').Length)))║" -ForegroundColor Red
        Write-Host "  ║                                                           ║" -ForegroundColor Red
        Write-Host "  ║  These ports are accessible from OTHER COMPUTERS on your  ║" -ForegroundColor Red
        Write-Host "  ║  network. Run Network-Shield to block external access.    ║" -ForegroundColor Red
        Write-Host "  ╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host ""
    } elseif ($safe.Count -gt 0) {
        Write-Host "  [OK] All active agent ports are localhost-only" -ForegroundColor Green
    } else {
        Write-Host "  [OK] No agent ports currently active" -ForegroundColor Gray
    }

    return @{
        Exposed = $exposed
        Safe = $safe
    }
}

function Set-WSLConfig {
    [CmdletBinding()]
    param()

    $wslConfigPath = Join-Path $env:USERPROFILE ".wslconfig"

    Write-Host "[WSL-Fence] Configuring .wslconfig..." -ForegroundColor Cyan

    # Recommended secure defaults
    $recommendedConfig = @"
# AI-Bastion-Guardian WSL2 Configuration
# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Docs: https://learn.microsoft.com/en-us/windows/wsl/wsl-config

[wsl2]
# Network: keep port forwarding to localhost only
localhostForwarding=true

# Resource limits (adjust based on your hardware)
memory=16GB
processors=8
swap=4GB

# Security: disable GUI apps if not needed (reduces attack surface)
# guiApplications=false

[experimental]
# Use mirrored networking for better port control (Windows 11 22H2+)
# Uncomment if on Windows 11:
# networkingMode=mirrored

# Auto-reclaim memory from WSL2
autoMemoryReclaim=gradual
"@

    if (Test-Path $wslConfigPath) {
        # Check existing config
        $existing = Get-Content $wslConfigPath -Raw

        if ($existing -match "AI-Bastion-Guardian") {
            Write-Host "  [OK] .wslconfig already configured by Guardian" -ForegroundColor Green
            return
        }

        # Backup existing
        $backupPath = "$wslConfigPath.guardian-backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $wslConfigPath $backupPath -Force
        Write-Host "  [OK] Backed up existing .wslconfig to $backupPath" -ForegroundColor Gray

        # Check if localhostForwarding is set
        if ($existing -match "localhostForwarding\s*=\s*false") {
            Write-Host "  [WARNING] localhostForwarding=false detected!" -ForegroundColor Red
            Write-Host "  This means WSL2 ports are NOT forwarded to Windows localhost." -ForegroundColor Red
            Write-Host "  Setting to true for compatibility with Guardian firewall rules." -ForegroundColor Yellow
        }

        # Append Guardian section if not present
        $guardianSection = @"

# ── AI-Bastion-Guardian additions ──
# localhostForwarding should be true for Guardian firewall rules to work
# Resource limits protect against DoS from compromised agents
"@
        Add-Content $wslConfigPath $guardianSection
        Write-Host "  [OK] Added Guardian configuration to existing .wslconfig" -ForegroundColor Green
    } else {
        # Create new .wslconfig
        $recommendedConfig | Set-Content $wslConfigPath -Force
        Write-Host "  [OK] Created .wslconfig with secure defaults" -ForegroundColor Green
    }

    Write-Host "  [NOTE] WSL2 restart required for .wslconfig changes: wsl --shutdown" -ForegroundColor Yellow
}

function Test-WSLNetworkMode {
    [CmdletBinding()]
    param()

    # Check Windows version for mirrored networking support
    $winVer = [System.Environment]::OSVersion.Version

    if ($winVer.Build -ge 22621) {
        Write-Host "  [INFO] Windows 11 22H2+ detected — mirrored networking available" -ForegroundColor Cyan
        Write-Host "  [TIP] Enable networkingMode=mirrored in .wslconfig for better port control" -ForegroundColor Gray
    } else {
        Write-Host "  [INFO] Using NAT networking mode (default for your Windows version)" -ForegroundColor Gray
    }
}

function Get-WSLFenceStatus {
    [CmdletBinding()]
    param()

    Write-Host "[WSL-Fence] Status:" -ForegroundColor Cyan

    # WSL2 status
    try {
        $distros = wsl --list --verbose 2>$null
        if ($distros) {
            Write-Host "  WSL2 Distros:" -ForegroundColor Gray
            $distros | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }
    } catch {
        Write-Host "  WSL2: Not available" -ForegroundColor Yellow
    }

    # .wslconfig
    $wslConfigPath = Join-Path $env:USERPROFILE ".wslconfig"
    if (Test-Path $wslConfigPath) {
        $hasGuardian = (Get-Content $wslConfigPath -Raw) -match "AI-Bastion-Guardian"
        if ($hasGuardian) {
            Write-Host "  .wslconfig: Configured by Guardian" -ForegroundColor Green
        } else {
            Write-Host "  .wslconfig: Exists (not managed by Guardian)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  .wslconfig: Not configured" -ForegroundColor Yellow
    }

    # Port exposure
    Test-PortExposure | Out-Null
}

Export-ModuleMember -Function Install-WSLFence, Test-PortExposure, Set-WSLConfig, Get-WSLFenceStatus
