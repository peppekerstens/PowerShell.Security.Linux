<#
.Synopsis
    Show ACL (permissions) for files in a directory.
.Description
    Demonstrates Get-LinuxAcl by listing files in /etc and showing their
    owner, group, and Unix permission mode in a formatted table.
.Notes
    Free to use under GNU v3 Public License (https://choosealicense.com/licenses/gpl-3.0/)
    Author: Peppe Kerstens (NLD)
    Requires: PowerShell.Security.Linux module
#>

param(
    [string]$Directory = '/etc'
)

if ($IsLinux) {
    $modulePath = Join-Path $PSScriptRoot '..' 'PowerShell.Security.Linux' 'PowerShell.Security.Linux.psd1'
    Import-Module $modulePath -Force -ErrorAction Stop
}

Write-Host "ACL report for: $Directory"
Write-Host ""

Get-ChildItem $Directory -File -ErrorAction SilentlyContinue |
    Select-Object -First 20 |
    Get-LinuxAcl |
    Select-Object UnixMode, Owner, Group,
        @{N='File'; E={ Split-Path $_.Path -Leaf }} |
    Format-Table -AutoSize
