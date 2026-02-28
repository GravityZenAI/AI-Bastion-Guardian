#Requires -RunAsAdministrator
# Quick install script for AI-Bastion-Guardian
# Usage: .\Install-Guardian.ps1 [-DryRun] [-Modules Network,Egress,Credentials,WSL]

[CmdletBinding()]
param(
    [switch]$DryRun,
    [string[]]$Modules = @("All")
)

$guardianScript = Join-Path $PSScriptRoot "..\guardian\Guardian.ps1"
& $guardianScript install -Modules $Modules -DryRun:$DryRun
