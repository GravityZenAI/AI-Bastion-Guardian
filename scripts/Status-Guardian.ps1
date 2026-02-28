# Show AI-Bastion-Guardian status (does not require admin)
# Usage: .\Status-Guardian.ps1

$guardianScript = Join-Path $PSScriptRoot "..\guardian\Guardian.ps1"
& $guardianScript status
