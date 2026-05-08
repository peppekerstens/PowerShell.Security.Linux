<#
.Synopsis
    Copy permissions from one file to another.
.Description
    Demonstrates a Get-LinuxAcl / Set-LinuxAcl round-trip: read the ACL from
    a source file and apply it to a target file. This mirrors the common
    Windows pattern of copying security descriptors between files.
.Notes
    Free to use under GNU v3 Public License (https://choosealicense.com/licenses/gpl-3.0/)
    Author: Peppe Kerstens (NLD)
    Requires: PowerShell.Security.Linux module
#>

param(
    [string]$SourceFile = '/etc/hosts',
    [string]$TargetFile = ([System.IO.Path]::GetTempFileName())
)

if ($IsLinux) {
    $modulePath = Join-Path $PSScriptRoot '..' 'PowerShell.Security.Linux' 'PowerShell.Security.Linux.psd1'
    Import-Module $modulePath -Force -ErrorAction Stop
}

# Read ACL from source
$sourceAcl = Get-LinuxAcl -Path $SourceFile
Write-Host "Source ACL ($SourceFile):"
Write-Host "  Owner   : $($sourceAcl.Owner)"
Write-Host "  Group   : $($sourceAcl.Group)"
Write-Host "  UnixMode: $($sourceAcl.UnixMode)"
Write-Host ""

# Apply to target (chmod only; chown requires elevated privileges)
Write-Host "Applying mode '$($sourceAcl.OctalMode)' to: $TargetFile"
Set-LinuxAcl -Path $TargetFile -AclObject $sourceAcl

$newAcl = Get-LinuxAcl -Path $TargetFile
Write-Host "Target ACL after Set-LinuxAcl:"
Write-Host "  UnixMode: $($newAcl.UnixMode)"
Write-Host "  OctalMode: $($newAcl.OctalMode)"

# Clean up temp file if we created it
if ($TargetFile -like '/tmp/tmp*') {
    Remove-Item $TargetFile -ErrorAction SilentlyContinue
}
