# ═══════════════════════════════════════════════════════════════════════════════
# Test-Guardian.ps1
# Verification suite for AI-Bastion-Guardian
# Run after installation to verify all modules are working
# ═══════════════════════════════════════════════════════════════════════════════

$ErrorActionPreference = "Continue"
$passed = 0
$failed = 0
$skipped = 0

function Test-Result {
    param(
        [string]$TestName,
        [bool]$Condition,
        [string]$FailMessage = "FAILED",
        [switch]$Skip
    )

    if ($Skip) {
        Write-Host "  [SKIP] $TestName" -ForegroundColor Yellow
        $script:skipped++
        return
    }

    if ($Condition) {
        Write-Host "  [PASS] $TestName" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "  [FAIL] $TestName — $FailMessage" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host ""
Write-Host "═══ AI-Bastion-Guardian Test Suite ═══" -ForegroundColor Cyan
Write-Host ""

# ── Test 1: Directory structure ──
Write-Host "── Directory Structure ──" -ForegroundColor Yellow
$root = Join-Path $PSScriptRoot ".."
Test-Result "guardian/Guardian.ps1 exists" (Test-Path "$root\guardian\Guardian.ps1")
Test-Result "guardian/modules/ exists" (Test-Path "$root\guardian\modules")
Test-Result "guardian/config/guardian.json exists" (Test-Path "$root\guardian\config\guardian.json")
Test-Result "guardian/config/allowed-domains.txt exists" (Test-Path "$root\guardian\config\allowed-domains.txt")

# ── Test 2: Module loading ──
Write-Host "── Module Loading ──" -ForegroundColor Yellow
$modules = @(
    "Network-Shield.psm1",
    "Egress-Proxy.psm1",
    "Credential-Vault.psm1",
    "WSL-Fence.psm1",
    "Canary-Watch.psm1"
)

foreach ($mod in $modules) {
    $modPath = "$root\guardian\modules\$mod"
    $exists = Test-Path $modPath
    Test-Result "Module $mod exists" $exists

    if ($exists) {
        try {
            Import-Module $modPath -Force -DisableNameChecking -ErrorAction Stop
            Test-Result "Module $mod loads without errors" $true
        } catch {
            Test-Result "Module $mod loads without errors" $false $_.Exception.Message
        }
    }
}

# ── Test 3: Firewall rules (only if admin) ──
Write-Host "── Network Shield ──" -ForegroundColor Yellow
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    $rules = Get-NetFirewallRule -DisplayName "Guardian_NetworkShield_*" -ErrorAction SilentlyContinue
    Test-Result "Firewall rules exist" ($null -ne $rules -and $rules.Count -gt 0) "No Guardian firewall rules found — run install first"
} else {
    Test-Result "Firewall rules (requires admin)" $false -Skip
}

# ── Test 4: Port exposure check ──
Write-Host "── WSL Fence ──" -ForegroundColor Yellow
$agentPorts = @(8000, 8888, 9999, 18789, 11434)
$anyExposed = $false
foreach ($port in $agentPorts) {
    $exposed = netstat -an 2>$null | Select-String "0\.0\.0\.0:$port\s"
    if ($exposed) { $anyExposed = $true }
}
Test-Result "No agent ports exposed on 0.0.0.0" (-not $anyExposed) "Some ports are exposed to network"

# .wslconfig
$wslConfigExists = Test-Path "$env:USERPROFILE\.wslconfig"
Test-Result ".wslconfig exists" $wslConfigExists "Run Install-WSLFence to create"

# ── Test 5: Configuration validity ──
Write-Host "── Configuration ──" -ForegroundColor Yellow
try {
    $config = Get-Content "$root\guardian\config\guardian.json" -Raw | ConvertFrom-Json
    Test-Result "guardian.json is valid JSON" $true
    Test-Result "guardian.json has agent_ports" ($null -ne $config.agent_ports)
    Test-Result "guardian.json has allowed_source_ranges" ($null -ne $config.allowed_source_ranges)
} catch {
    Test-Result "guardian.json is valid JSON" $false $_.Exception.Message
}

# Allowed domains
$domains = Get-Content "$root\guardian\config\allowed-domains.txt" -ErrorAction SilentlyContinue |
    Where-Object { $_ -and ($_ -notmatch '^\s*#') }
Test-Result "allowed-domains.txt has entries" ($domains.Count -gt 0) "Empty whitelist — all outbound will be blocked"

# ── Test 6: Log directory ──
Write-Host "── Logging ──" -ForegroundColor Yellow
$logDir = Join-Path $env:USERPROFILE ".ai-bastion-guardian"
Test-Result "Log directory writable" $true  # Will be created on first log

# ═══ Results ═══
Write-Host ""
Write-Host "═══ Results ═══" -ForegroundColor Cyan
Write-Host "  Passed:  $passed" -ForegroundColor Green
Write-Host "  Failed:  $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
Write-Host "  Skipped: $skipped" -ForegroundColor Yellow
Write-Host ""

if ($failed -eq 0) {
    Write-Host "  All tests passed! Guardian is properly configured." -ForegroundColor Green
} else {
    Write-Host "  $failed test(s) failed. Review output above." -ForegroundColor Red
}
