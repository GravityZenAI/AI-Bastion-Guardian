# ═══════════════════════════════════════════════════════════════════════════════
# Credential-Vault.psm1
# Moves sensitive API keys from .env files to Windows Credential Manager
# Replaces values with SECURED_BY_GUARDIAN placeholder
# ═══════════════════════════════════════════════════════════════════════════════

$script:GuardianPrefix = "Guardian_Vault"

# Patterns that indicate sensitive values
$script:SensitivePatterns = @(
    "KEY",
    "TOKEN",
    "SECRET",
    "PASSWORD",
    "PASSWD",
    "API_KEY",
    "APIKEY",
    "AUTH",
    "CREDENTIAL"
)

function Protect-AgentCredentials {
    [CmdletBinding()]
    param(
        [string]$EnvFilePath
    )

    Write-Host "[Credential-Vault] Securing API keys..." -ForegroundColor Cyan

    # If no path provided, search common locations
    if (-not $EnvFilePath) {
        $searchPaths = @(
            (Join-Path $env:USERPROFILE ".env"),
            (Join-Path $env:USERPROFILE ".openclaw\.env"),
            (Join-Path $env:USERPROFILE "openclaw\.env"),
            (Join-Path $env:USERPROFILE ".config\openclaw\.env")
        )

        # Also search WSL2 home via \\wsl$
        $wslPaths = @(
            "\\wsl$\Ubuntu\home\*\.env",
            "\\wsl$\Ubuntu\home\*\.openclaw\.env"
        )

        foreach ($wslPattern in $wslPaths) {
            $found = Resolve-Path $wslPattern -ErrorAction SilentlyContinue
            if ($found) { $searchPaths += $found.Path }
        }

        $envFiles = $searchPaths | Where-Object { Test-Path $_ }

        if ($envFiles.Count -eq 0) {
            Write-Host "[Credential-Vault] No .env files found in default locations" -ForegroundColor Yellow
            Write-Host "[Credential-Vault] Run with -EnvFilePath to specify location" -ForegroundColor Yellow
            return
        }
    } else {
        if (-not (Test-Path $EnvFilePath)) {
            Write-Host "[Credential-Vault] File not found: $EnvFilePath" -ForegroundColor Red
            return
        }
        $envFiles = @($EnvFilePath)
    }

    $totalSecured = 0

    foreach ($envFile in $envFiles) {
        Write-Host "[Credential-Vault] Processing: $envFile" -ForegroundColor Cyan

        # Create backup
        $backupPath = "$envFile.guardian-backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $envFile $backupPath -Force
        Write-Host "  [OK] Backup: $backupPath" -ForegroundColor Gray

        $lines = Get-Content $envFile
        $newLines = @()
        $secured = 0

        foreach ($line in $lines) {
            # Skip comments and empty lines
            if ($line -match '^\s*#' -or $line -match '^\s*$') {
                $newLines += $line
                continue
            }

            # Match KEY=VALUE pattern
            if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$') {
                $varName = $Matches[1]
                $varValue = $Matches[2].Trim().Trim('"').Trim("'")

                # Check if this is a sensitive variable
                $isSensitive = $false
                foreach ($pattern in $script:SensitivePatterns) {
                    if ($varName -match $pattern) {
                        $isSensitive = $true
                        break
                    }
                }

                if ($isSensitive -and $varValue -ne "SECURED_BY_GUARDIAN" -and $varValue.Length -gt 0) {
                    # Store in Windows Credential Manager
                    $credTarget = "${script:GuardianPrefix}_${varName}"

                    try {
                        # Remove existing if present
                        cmdkey /delete:$credTarget 2>$null | Out-Null

                        # Store new credential
                        cmdkey /generic:$credTarget /user:$varName /pass:$varValue 2>$null | Out-Null

                        # Replace in file
                        $newLines += "$varName=SECURED_BY_GUARDIAN"
                        $secured++

                        $maskedValue = $varValue.Substring(0, [Math]::Min(4, $varValue.Length)) + "****"
                        Write-Host "  [SECURED] $varName ($maskedValue → Credential Manager)" -ForegroundColor Green
                    } catch {
                        Write-Host "  [FAIL] $varName — $($_.Exception.Message)" -ForegroundColor Red
                        $newLines += $line
                    }
                } else {
                    $newLines += $line
                }
            } else {
                $newLines += $line
            }
        }

        if ($secured -gt 0) {
            $newLines | Set-Content $envFile -Force
            Write-Host "  [OK] Secured $secured keys from $envFile" -ForegroundColor Green
            $totalSecured += $secured
        } else {
            Write-Host "  [OK] No unsecured sensitive keys found" -ForegroundColor Gray
        }
    }

    Write-Host "[Credential-Vault] Total secured: $totalSecured keys across $($envFiles.Count) files" -ForegroundColor Cyan
}

function Restore-AgentCredentials {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EnvFilePath
    )

    Write-Host "[Credential-Vault] Restoring credentials to $EnvFilePath..." -ForegroundColor Yellow

    if (-not (Test-Path $EnvFilePath)) {
        Write-Host "[Credential-Vault] File not found: $EnvFilePath" -ForegroundColor Red
        return
    }

    $lines = Get-Content $EnvFilePath
    $newLines = @()
    $restored = 0

    foreach ($line in $lines) {
        if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*SECURED_BY_GUARDIAN\s*$') {
            $varName = $Matches[1]
            $credTarget = "${script:GuardianPrefix}_${varName}"

            # Retrieve from Credential Manager
            $stored = cmdkey /list:$credTarget 2>$null
            if ($stored -match "Password") {
                # cmdkey doesn't expose passwords in plain text for security
                # User needs to use the backup file to restore
                Write-Host "  [NOTE] $varName — use backup file to restore value" -ForegroundColor Yellow
                $newLines += $line
            } else {
                $newLines += $line
            }
        } else {
            $newLines += $line
        }
    }

    Write-Host "[Credential-Vault] To fully restore, use the .guardian-backup file" -ForegroundColor Yellow
}

function Get-VaultStatus {
    [CmdletBinding()]
    param()

    $creds = cmdkey /list 2>$null | Select-String "${script:GuardianPrefix}_"
    $count = if ($creds) { $creds.Count } else { 0 }

    Write-Host "[Credential-Vault] $count credentials secured in Windows Credential Manager" -ForegroundColor Cyan

    if ($creds) {
        foreach ($cred in $creds) {
            $name = ($cred -replace ".*${script:GuardianPrefix}_", "").Trim()
            Write-Host "  [SECURED] $name" -ForegroundColor Green
        }
    }
}

Export-ModuleMember -Function Protect-AgentCredentials, Restore-AgentCredentials, Get-VaultStatus
