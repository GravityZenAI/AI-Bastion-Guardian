#Requires -RunAsAdministrator
# ═══════════════════════════════════════════════════════════════════════════════
# AI-Bastion-Guardian v1.0.0
# Windows-side security for AI agents running in WSL2 or native Windows
# Apache 2.0 — GravityZen AI
# ═══════════════════════════════════════════════════════════════════════════════

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("install", "uninstall", "status", "help")]
    [string]$Action = "help",

    [switch]$DryRun,

    [ValidateSet("Network", "Egress", "Credentials", "WSL", "All")]
    [string[]]$Modules = @("All")
)

$ErrorActionPreference = "Stop"
$script:GuardianVersion = "1.0.0"
$script:GuardianRoot = $PSScriptRoot
$script:LogFile = Join-Path $env:USERPROFILE ".ai-bastion-guardian\guardian.log"

# ═══════════════════════════════════════════════════════════════════════════════
# BANNER
# ═══════════════════════════════════════════════════════════════════════════════

function Show-Banner {
    Write-Host @"

    ╔═══════════════════════════════════════════════════════════╗
    ║                                                           ║
    ║   AI-Bastion-Guardian v$script:GuardianVersion                       ║
    ║   Windows Security for AI Agents                          ║
    ║                                                           ║
    ║   GravityZen AI — Apache 2.0                              ║
    ╚═══════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan
}

# ═══════════════════════════════════════════════════════════════════════════════
# LOGGING
# ═══════════════════════════════════════════════════════════════════════════════

function Write-GuardianLog {
    param([string]$Message, [string]$Level = "INFO")

    $logDir = Split-Path $script:LogFile -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $script:LogFile -Value $entry

    switch ($Level) {
        "INFO"    { Write-Host "[Guardian] $Message" -ForegroundColor Green }
        "WARN"    { Write-Host "[Guardian] $Message" -ForegroundColor Yellow }
        "ERROR"   { Write-Host "[Guardian] $Message" -ForegroundColor Red }
        "DRY"     { Write-Host "[DRY RUN] $Message" -ForegroundColor Magenta }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# MODULE LOADER
# ═══════════════════════════════════════════════════════════════════════════════

function Import-GuardianModules {
    $modulePath = Join-Path $script:GuardianRoot "modules"
    $moduleFiles = @(
        "Network-Shield.psm1",
        "Egress-Proxy.psm1",
        "Credential-Vault.psm1",
        "WSL-Fence.psm1"
    )

    foreach ($mod in $moduleFiles) {
        $fullPath = Join-Path $modulePath $mod
        if (Test-Path $fullPath) {
            Import-Module $fullPath -Force -DisableNameChecking
            Write-Verbose "Loaded module: $mod"
        } else {
            Write-GuardianLog "Module not found: $mod" "WARN"
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# ACTIONS
# ═══════════════════════════════════════════════════════════════════════════════

function Invoke-GuardianInstall {
    param([string[]]$SelectedModules, [switch]$DryRun)

    if ($SelectedModules -contains "All") {
        $SelectedModules = @("Network", "Egress", "Credentials", "WSL")
    }

    Write-GuardianLog "Installing modules: $($SelectedModules -join ', ')" "INFO"

    foreach ($mod in $SelectedModules) {
        Write-Host ""
        Write-Host "═══ Module: $mod ═══" -ForegroundColor Yellow

        switch ($mod) {
            "Network" {
                if ($DryRun) {
                    Write-GuardianLog "Would install Network Shield (firewall rules for agent ports)" "DRY"
                } else {
                    Install-NetworkShield
                }
            }
            "Egress" {
                if ($DryRun) {
                    Write-GuardianLog "Would install Egress Proxy (outbound domain whitelist)" "DRY"
                } else {
                    Install-EgressProxy
                }
            }
            "Credentials" {
                if ($DryRun) {
                    Write-GuardianLog "Would secure credentials (move API keys to Credential Manager)" "DRY"
                } else {
                    Protect-AgentCredentials
                }
            }
            "WSL" {
                if ($DryRun) {
                    Write-GuardianLog "Would install WSL Fence (port exposure detection + .wslconfig)" "DRY"
                } else {
                    Install-WSLFence
                }
            }
        }
    }

    Write-Host ""
    Write-GuardianLog "Installation complete. Run 'Guardian.ps1 status' to verify." "INFO"
}

function Invoke-GuardianUninstall {
    Write-GuardianLog "Removing all Guardian firewall rules..." "WARN"

    $rules = Get-NetFirewallRule -DisplayName "Guardian_*" -ErrorAction SilentlyContinue
    if ($rules) {
        $rules | Remove-NetFirewallRule
        Write-GuardianLog "Removed $($rules.Count) firewall rules" "INFO"
    } else {
        Write-GuardianLog "No Guardian firewall rules found" "INFO"
    }

    # Remove stored credentials
    $creds = cmdkey /list 2>$null | Select-String "Guardian_"
    if ($creds) {
        $creds | ForEach-Object {
            $target = ($_ -replace '.*Target:\s*', '').Trim()
            cmdkey /delete:$target 2>$null | Out-Null
        }
        Write-GuardianLog "Removed stored credentials" "INFO"
    }

    Write-GuardianLog "Uninstall complete. Your system is back to default." "INFO"
}

function Show-GuardianStatus {
    Write-Host "═══ Guardian Status ═══" -ForegroundColor Yellow
    Write-Host ""

    # 1. Firewall rules
    $rules = Get-NetFirewallRule -DisplayName "Guardian_*" -ErrorAction SilentlyContinue
    $ruleCount = if ($rules) { $rules.Count } else { 0 }
    $ruleColor = if ($ruleCount -gt 0) { "Green" } else { "Red" }
    Write-Host "  Firewall rules:     $ruleCount active" -ForegroundColor $ruleColor

    # 2. Exposed agent ports
    $agentPorts = @(8000, 8888, 9999, 18789)
    $exposed = @()
    foreach ($port in $agentPorts) {
        $found = netstat -an 2>$null | Select-String "0\.0\.0\.0:$port\s"
        if ($found) { $exposed += $port }
    }
    if ($exposed.Count -gt 0) {
        Write-Host "  Exposed ports:      WARNING — $($exposed -join ', ') on 0.0.0.0" -ForegroundColor Red
    } else {
        Write-Host "  Exposed ports:      None (good)" -ForegroundColor Green
    }

    # 3. Secured credentials
    $securedCreds = (cmdkey /list 2>$null | Select-String "Guardian_").Count
    $credColor = if ($securedCreds -gt 0) { "Green" } else { "Yellow" }
    Write-Host "  Secured credentials: $securedCreds in Credential Manager" -ForegroundColor $credColor

    # 4. WSL2 status
    $wslRunning = $false
    try {
        $wslStatus = wsl --list --running 2>$null
        $wslRunning = $wslStatus -and ($wslStatus -match "Ubuntu|Debian")
    } catch {}
    $wslColor = if ($wslRunning) { "Green" } else { "Yellow" }
    $wslText = if ($wslRunning) { "Running" } else { "Not running or not installed" }
    Write-Host "  WSL2:               $wslText" -ForegroundColor $wslColor

    # 5. .wslconfig
    $wslConfigExists = Test-Path "$env:USERPROFILE\.wslconfig"
    $wcColor = if ($wslConfigExists) { "Green" } else { "Yellow" }
    $wcText = if ($wslConfigExists) { "Present" } else { "Not configured" }
    Write-Host "  .wslconfig:         $wcText" -ForegroundColor $wcColor

    # 6. Log file
    if (Test-Path $script:LogFile) {
        $logSize = (Get-Item $script:LogFile).Length / 1KB
        Write-Host "  Log file:           $([math]::Round($logSize, 1)) KB" -ForegroundColor Gray
    }

    Write-Host ""
}

function Show-Help {
    Write-Host @"
USAGE:
  .\Guardian.ps1 install [-Modules Network,Egress,Credentials,WSL] [-DryRun]
  .\Guardian.ps1 uninstall
  .\Guardian.ps1 status
  .\Guardian.ps1 help

MODULES:
  Network      Windows Firewall rules to block external access to agent ports
  Egress       Outbound connection control with domain whitelist
  Credentials  Move API keys from .env to Windows Credential Manager
  WSL          WSL2 port exposure detection + .wslconfig hardening
  All          Install all modules (default)

FLAGS:
  -DryRun      Show what would be done without making changes

EXAMPLES:
  .\Guardian.ps1 install                         # Install all modules
  .\Guardian.ps1 install -Modules Network,WSL    # Only firewall + WSL
  .\Guardian.ps1 install -DryRun                 # Preview changes
  .\Guardian.ps1 status                          # Show current protection
  .\Guardian.ps1 uninstall                       # Remove all protections

"@ -ForegroundColor White
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

Show-Banner
Import-GuardianModules

switch ($Action) {
    "install"   { Invoke-GuardianInstall -SelectedModules $Modules -DryRun:$DryRun }
    "uninstall" { Invoke-GuardianUninstall }
    "status"    { Show-GuardianStatus }
    "help"      { Show-Help }
}
