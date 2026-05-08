#Requires -Version 7.2

# PowerShell.Security.Linux.psm1
# Root module for PowerShell.Security.Linux.
# Dot-sources all function files.

# Linux-only guard — this module wraps Linux CLI tools (stat, chmod, chown, getfacl, setfacl)
# and must not be loaded on Windows. On Windows, use the built-in Security module:
#   Import-Module Microsoft.PowerShell.Security
if (-not $IsLinux) {
    throw (
        "PowerShell.Security.Linux cannot be loaded on Windows. " +
        "On Windows, use the built-in 'Microsoft.PowerShell.Security' module.`n" +
        "PowerShell.Security.Linux is a Linux-only peer module that wraps stat, chmod, chown, and getfacl."
    )
}

$functionPath = Join-Path $PSScriptRoot 'Functions'
$functionFiles = Get-ChildItem -Path $functionPath -Filter '*.ps1' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notlike '*.Tests.ps1' }
foreach ($file in $functionFiles) {
    . $file.FullName
}

# Microsoft.PowerShell.Security / ACL compatibility aliases
Set-Alias -Name 'Get-Acl' -Value 'Get-LinuxAcl'
Set-Alias -Name 'Set-Acl' -Value 'Set-LinuxAcl'
