<#
.Synopsis
    Find world-writable files in a directory.
.Description
    Demonstrates using Get-LinuxAcl to audit files where 'other' has write
    permission — a common security concern. The 'other' entry permissions
    containing 'w' indicates world-writable.
.Notes
    Free to use under GNU v3 Public License (https://choosealicense.com/licenses/gpl-3.0/)
    Author: Peppe Kerstens (NLD)
    Requires: PowerShell.Security.Linux module
#>

param(
    [string]$Directory = '/tmp'
)

if ($IsLinux) {
    $modulePath = Join-Path $PSScriptRoot '..' 'PowerShell.Security.Linux' 'PowerShell.Security.Linux.psd1'
    Import-Module $modulePath -Force -ErrorAction Stop
}

$worldWritable = Get-ChildItem $Directory -ErrorAction SilentlyContinue |
    Get-LinuxAcl |
    Where-Object {
        $otherEntry = $_.Access | Where-Object { $_.EntryType -eq 'other' }
        $otherEntry -and $otherEntry.Permissions[1] -eq 'w'
    }

if (-not $worldWritable) {
    Write-Host "No world-writable files found in '$Directory'."
} else {
    Write-Host "World-writable files in '$Directory':"
    $worldWritable | Select-Object @{N='Path'; E={ $_.Path }}, Owner, UnixMode |
        Format-Table -AutoSize
}
