# ═══════════════════════════════════════════════════════════════════════════════
# Network-Shield.psm1
# Blocks external access to AI agent ports via Windows Firewall
# Only allows connections from localhost (127.0.0.0/8) and WSL2 (172.16.0.0/12)
# ═══════════════════════════════════════════════════════════════════════════════

$script:GuardianPrefix = "Guardian_NetworkShield"

# Default agent ports — override via guardian.json
$script:DefaultAgentPorts = @(
    @{ Port = 8000;  Name = "FastAPI/Uvicorn" },
    @{ Port = 8888;  Name = "Jupyter/Agent UI" },
    @{ Port = 9999;  Name = "OpenClaw Gateway" },
    @{ Port = 18789; Name = "OpenClaw Default" },
    @{ Port = 11434; Name = "Ollama API" },
    @{ Port = 3000;  Name = "Dev Server" },
    @{ Port = 8080;  Name = "HTTP Proxy" }
)

# Safe source ranges
$script:AllowedRemoteAddresses = @(
    "127.0.0.0/8",      # Localhost
    "172.16.0.0/12",     # WSL2 subnet (Hyper-V internal)
    "192.168.0.0/16"     # Local network (optional — remove for stricter)
)

function Install-NetworkShield {
    [CmdletBinding()]
    param()

    Write-Host "[Network-Shield] Installing firewall rules..." -ForegroundColor Cyan

    # Load custom config if exists
    $configPath = Join-Path $PSScriptRoot "..\config\guardian.json"
    $ports = $script:DefaultAgentPorts

    if (Test-Path $configPath) {
        try {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            if ($config.agent_ports) {
                $ports = @()
                foreach ($p in $config.agent_ports) {
                    $ports += @{ Port = $p.port; Name = $p.name }
                }
                Write-Host "[Network-Shield] Loaded custom ports from guardian.json" -ForegroundColor Green
            }
        } catch {
            Write-Host "[Network-Shield] Could not parse guardian.json, using defaults" -ForegroundColor Yellow
        }
    }

    # Remove existing Guardian rules first
    Remove-NetworkShield -Silent

    foreach ($entry in $ports) {
        $port = $entry.Port
        $name = $entry.Name
        $ruleName = "${script:GuardianPrefix}_Block_${port}"

        try {
            # Block ALL inbound to this port
            New-NetFirewallRule `
                -DisplayName $ruleName `
                -Direction Inbound `
                -Protocol TCP `
                -LocalPort $port `
                -Action Block `
                -Profile Any `
                -Description "Guardian: Block external access to $name (port $port)" `
                -ErrorAction Stop | Out-Null

            # Allow from safe ranges
            $allowRuleName = "${script:GuardianPrefix}_Allow_${port}"
            New-NetFirewallRule `
                -DisplayName $allowRuleName `
                -Direction Inbound `
                -Protocol TCP `
                -LocalPort $port `
                -Action Allow `
                -RemoteAddress $script:AllowedRemoteAddresses `
                -Profile Any `
                -Description "Guardian: Allow local/WSL2 access to $name (port $port)" `
                -ErrorAction Stop | Out-Null

            Write-Host "  [OK] Port $port ($name) — blocked external, allowed local/WSL2" -ForegroundColor Green
        } catch {
            Write-Host "  [FAIL] Port $port ($name) — $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host "[Network-Shield] Done. $($ports.Count) ports protected." -ForegroundColor Cyan
}

function Remove-NetworkShield {
    [CmdletBinding()]
    param([switch]$Silent)

    $existing = Get-NetFirewallRule -DisplayName "${script:GuardianPrefix}_*" -ErrorAction SilentlyContinue
    if ($existing) {
        $existing | Remove-NetFirewallRule -ErrorAction SilentlyContinue
        if (-not $Silent) {
            Write-Host "[Network-Shield] Removed $($existing.Count) existing rules" -ForegroundColor Yellow
        }
    }
}

function Get-NetworkShieldStatus {
    [CmdletBinding()]
    param()

    $rules = Get-NetFirewallRule -DisplayName "${script:GuardianPrefix}_*" -ErrorAction SilentlyContinue
    if ($rules) {
        Write-Host "[Network-Shield] Active rules:" -ForegroundColor Cyan
        foreach ($rule in $rules) {
            $portFilter = $rule | Get-NetFirewallPortFilter
            $status = if ($rule.Enabled -eq 'True') { "ON" } else { "OFF" }
            Write-Host "  [$status] $($rule.DisplayName) — Port $($portFilter.LocalPort) — $($rule.Action)" -ForegroundColor Green
        }
    } else {
        Write-Host "[Network-Shield] No rules installed" -ForegroundColor Yellow
    }
}

Export-ModuleMember -Function Install-NetworkShield, Remove-NetworkShield, Get-NetworkShieldStatus
