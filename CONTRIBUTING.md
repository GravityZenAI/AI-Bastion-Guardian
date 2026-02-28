# Contributing to AI-Bastion-Guardian

Thank you for your interest in making AI agents more secure on Windows.

## How to Contribute

### Reporting Bugs

1. Check [existing issues](https://github.com/GravityZenAI/AI-Bastion-Guardian/issues) first
2. Open a new issue with:
   - Windows version (10/11, build number)
   - PowerShell version (`$PSVersionTable.PSVersion`)
   - Steps to reproduce
   - Expected vs actual behavior

### Suggesting Features

Open an issue with the `enhancement` label. Describe the security problem it solves and how it fits with Guardian's existing modules.

### Submitting Code

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Run the test suite: `.\tests\Test-Guardian.ps1`
5. Commit with a descriptive message
6. Open a Pull Request

## Development Setup

### Requirements

- Windows 10 21H2+ or Windows 11
- PowerShell 5.1+ (built into Windows)
- Administrator privileges (for testing firewall rules)
- Optional: WSL2 with Ubuntu (for testing WSL-Fence)

### Testing Your Changes

```powershell
# Run the full test suite
.\tests\Test-Guardian.ps1

# Test a specific module in dry-run mode
.\guardian\Guardian.ps1 install -Modules Network -DryRun

# Verify no existing rules are broken
.\guardian\Guardian.ps1 status
```

### Adding a New Module

1. Create `guardian/modules/Your-Module.psm1`
2. Export functions: `Install-YourModule`, `Remove-YourModule`, `Get-YourModuleStatus`
3. Register it in `Guardian.ps1` (add to the switch statement in `Invoke-GuardianInstall`)
4. Add tests in `tests/Test-Guardian.ps1`
5. Document in README.md

## Code Style

- Use PowerShell verb-noun naming: `Install-`, `Remove-`, `Get-`, `Test-`
- Prefix all firewall rules with `Guardian_ModuleName_`
- Include `-ErrorAction` on all external commands
- Log important actions with `Write-Host` using color coding:
  - Green: Success
  - Yellow: Warning / Info
  - Red: Error
  - Cyan: Section headers

## Security

If you find a security vulnerability, **DO NOT** open a public issue. See [SECURITY.md](SECURITY.md).

## License

By contributing, you agree that your contributions will be licensed under the Apache 2.0 License.
