# ═══════════════════════════════════════════════════════════════════════════════
# Egress-Proxy.psm1
# Controls outbound connections from AI agent processes
# Uses Windows Firewall outbound rules to enforce domain whitelist
# ═══════════════════════════════════════════════════════════════════════════════

$script:GuardianPrefix = "Guardian_EgressProxy"

# Processes that should be restricted to whitelist only
$script:AgentProcesses = @(
    "node",
    "python",
    "python3",
    "ollama",
    "uvicorn",
    "openclaw"
)

function Install-EgressProxy {
    [CmdletBinding()]
    param()

    Write-Host "[Egress-Proxy] Installing outbound controls..." -ForegroundColor Cyan

    # Load allowed domains
    $domainsFile = Join-Path $PSScriptRoot "..\config\allowed-domains.txt"
    if (-not (Test-Path $domainsFile)) {
        Write-Host "[Egress-Proxy] ERROR: allowed-domains.txt not found at $domainsFile" -ForegroundColor Red
        Write-Host "[Egress-Proxy] Create it with one domain per line (e.g., api.anthropic.com)" -ForegroundColor Yellow
        return
    }

    $domains = Get-Content $domainsFile | Where-Object {
        $_ -and ($_ -notmatch '^\s*#') -and ($_.Trim() -ne '')
    } | ForEach-Object { $_.Trim() }

    if ($domains.Count -eq 0) {
        Write-Host "[Egress-Proxy] WARNING: No domains in whitelist. All outbound will be blocked." -ForegroundColor Red
        return
    }

    Write-Host "[Egress-Proxy] Resolving $($domains.Count) allowed domains to IPs..." -ForegroundColor Cyan

    # Resolve domains to IPs
    $allowedIPs = @()
    foreach ($domain in $domains) {
        try {
            $resolved = [System.Net.Dns]::GetHostAddresses($domain) |
                Where-Object { $_.AddressFamily -eq 'InterNetwork' } |
                ForEach-Object { $_.IPAddressToString }

            if ($resolved) {
                $allowedIPs += $resolved
                Write-Host "  [OK] $domain → $($resolved -join ', ')" -ForegroundColor Green
            } else {
                Write-Host "  [SKIP] $domain — no IPv4 address found" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  [FAIL] $domain — DNS resolution failed" -ForegroundColor Red
        }
    }

    # Always allow localhost and WSL2 subnet
    $allowedIPs += @("127.0.0.1", "172.16.0.0/12", "192.168.0.0/16", "10.0.0.0/8")

    # Deduplicate
    $allowedIPs = $allowedIPs | Sort-Object -Unique

    Write-Host "[Egress-Proxy] Total allowed IPs: $($allowedIPs.Count)" -ForegroundColor Cyan

    # Remove existing egress rules
    Remove-EgressProxy -Silent

    # Create BLOCK ALL outbound rule for each agent process
    foreach ($proc in $script:AgentProcesses) {
        $blockRuleName = "${script:GuardianPrefix}_BlockAll_${proc}"

        # Find process executable path (best effort)
        $exePath = Get-AgentExecutablePath -ProcessName $proc

        if (-not $exePath) {
            Write-Host "  [SKIP] $proc — executable not found on this system" -ForegroundColor Yellow
            continue
        }

        try {
            # Block all outbound for this process
            New-NetFirewallRule `
                -DisplayName $blockRuleName `
                -Direction Outbound `
                -Program $exePath `
                -Action Block `
                -Profile Any `
                -Description "Guardian: Block all outbound from $proc" `
                -ErrorAction Stop | Out-Null

            # Allow outbound to whitelisted IPs only
            $allowRuleName = "${script:GuardianPrefix}_AllowWhitelist_${proc}"
            New-NetFirewallRule `
                -DisplayName $allowRuleName `
                -Direction Outbound `
                -Program $exePath `
                -Action Allow `
                -RemoteAddress $allowedIPs `
                -Profile Any `
                -Description "Guardian: Allow $proc to whitelisted domains only" `
                -ErrorAction Stop | Out-Null

            Write-Host "  [OK] $proc ($exePath) — restricted to whitelist" -ForegroundColor Green
        } catch {
            Write-Host "  [FAIL] $proc — $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host "[Egress-Proxy] Done. Outbound controls active." -ForegroundColor Cyan
    Write-Host "[Egress-Proxy] NOTE: Domain IPs may change. Re-run periodically to update." -ForegroundColor Yellow
}

function Get-AgentExecutablePath {
    [CmdletBinding()]
    param([string]$ProcessName)

    # Try to find the executable
    $searchPaths = @(
        (Get-Command $ProcessName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
        (Join-Path $env:LOCALAPPDATA "Programs\$ProcessName\$ProcessName.exe"),
        (Join-Path $env:ProgramFiles "$ProcessName\$ProcessName.exe"),
        (Join-Path $env:ProgramFiles "(x86)\$ProcessName\$ProcessName.exe")
    )

    # Also check running processes
    $running = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty Path -ErrorAction SilentlyContinue

    if ($running) { return $running }

    foreach ($path in $searchPaths) {
        if ($path -and (Test-Path $path)) {
            return $path
        }
    }

    return $null
}

function Remove-EgressProxy {
    [CmdletBinding()]
    param([switch]$Silent)

    $existing = Get-NetFirewallRule -DisplayName "${script:GuardianPrefix}_*" -ErrorAction SilentlyContinue
    if ($existing) {
        $existing | Remove-NetFirewallRule -ErrorAction SilentlyContinue
        if (-not $Silent) {
            Write-Host "[Egress-Proxy] Removed $($existing.Count) existing rules" -ForegroundColor Yellow
        }
    }
}

function Get-EgressProxyStatus {
    [CmdletBinding()]
    param()

    $rules = Get-NetFirewallRule -DisplayName "${script:GuardianPrefix}_*" -ErrorAction SilentlyContinue
    if ($rules) {
        Write-Host "[Egress-Proxy] Active rules:" -ForegroundColor Cyan
        $blockRules = $rules | Where-Object { $_.Action -eq 'Block' }
        $allowRules = $rules | Where-Object { $_.Action -eq 'Allow' }
        Write-Host "  Block rules: $($blockRules.Count)" -ForegroundColor Red
        Write-Host "  Allow rules: $($allowRules.Count)" -ForegroundColor Green
    } else {
        Write-Host "[Egress-Proxy] No rules installed" -ForegroundColor Yellow
    }
}

Export-ModuleMember -Function Install-EgressProxy, Remove-EgressProxy, Get-EgressProxyStatus
