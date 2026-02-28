# ═══════════════════════════════════════════════════════════════════════════════
# Logger.ps1
# Shared logging utilities for Guardian modules
# ═══════════════════════════════════════════════════════════════════════════════

$script:DefaultLogDir = Join-Path $env:USERPROFILE ".ai-bastion-guardian"
$script:DefaultLogFile = Join-Path $script:DefaultLogDir "guardian.log"

function Initialize-GuardianLog {
    [CmdletBinding()]
    param([string]$LogDir = $script:DefaultLogDir)

    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
}

function Write-GuardianEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO", "WARN", "ERROR", "CRITICAL", "DEBUG")]
        [string]$Level = "INFO",

        [string]$Module = "Guardian",

        [string]$LogFile = $script:DefaultLogFile
    )

    Initialize-GuardianLog

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $entry = "[$timestamp] [$Level] [$Module] $Message"

    Add-Content -Path $LogFile -Value $entry -ErrorAction SilentlyContinue

    # Also write to Windows Event Log if critical
    if ($Level -eq "CRITICAL") {
        try {
            if (-not [System.Diagnostics.EventLog]::SourceExists("AI-Bastion-Guardian")) {
                [System.Diagnostics.EventLog]::CreateEventSource("AI-Bastion-Guardian", "Application")
            }
            Write-EventLog -LogName "Application" -Source "AI-Bastion-Guardian" `
                -EventID 9001 -EntryType Error -Message $Message
        } catch {
            # Event log write failed — not critical
        }
    }
}

function Get-GuardianLog {
    [CmdletBinding()]
    param(
        [int]$Lines = 50,
        [string]$Level,
        [string]$LogFile = $script:DefaultLogFile
    )

    if (-not (Test-Path $LogFile)) {
        Write-Host "No log file found at $LogFile" -ForegroundColor Yellow
        return
    }

    $content = Get-Content $LogFile -Tail $Lines

    if ($Level) {
        $content = $content | Where-Object { $_ -match "\[$Level\]" }
    }

    return $content
}

function Clear-GuardianLog {
    [CmdletBinding()]
    param([string]$LogFile = $script:DefaultLogFile)

    if (Test-Path $LogFile) {
        $backupPath = "$LogFile.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Move-Item $LogFile $backupPath -Force
        Write-Host "Log archived to $backupPath" -ForegroundColor Gray
    }
}
