<#
.Synopsis
    Find files not owned by root in system directories.
.Description
    Demonstrates filtering Get-LinuxAcl results to identify files where
    the owner is not root — a common security audit pattern.
.Notes
    Free to use under GNU v3 Public License (https://choosealicense.com/licenses/gpl-3.0/)
    Author: Peppe Kerstens (NLD)
    Requires: PowerShell.Security.Linux module
#>

param(
    [string]$Directory = '/etc',
    [string]$ExpectedOwner = 'root'
)

if ($IsLinux) {
    $modulePath = Join-Path $PSScriptRoot '..' 'PowerShell.Security.Linux' 'PowerShell.Security.Linux.psd1'
    Import-Module $modulePath -Force -ErrorAction Stop
}

$results = Get-ChildItem $Directory -File -ErrorAction SilentlyContinue |
    Get-LinuxAcl |
    Where-Object { $_.Owner -ne $ExpectedOwner }

if (-not $results) {
    Write-Host "All files in '$Directory' are owned by '$ExpectedOwner'."
} else {
    Write-Host "Files in '$Directory' not owned by '$ExpectedOwner':"
    $results | Select-Object @{N='File'; E={ $_.Path }}, Owner, Group, UnixMode |
        Format-Table -AutoSize
}
