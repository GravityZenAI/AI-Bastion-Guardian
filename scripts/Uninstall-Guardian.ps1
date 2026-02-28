#Requires -RunAsAdministrator
# Uninstall AI-Bastion-Guardian — removes all firewall rules and credentials
# Usage: .\Uninstall-Guardian.ps1

$guardianScript = Join-Path $PSScriptRoot "..\guardian\Guardian.ps1"
& $guardianScript uninstall
