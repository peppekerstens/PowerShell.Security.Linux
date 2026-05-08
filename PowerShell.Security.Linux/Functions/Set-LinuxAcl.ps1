function Set-LinuxAcl {
    <#
    .Synopsis
        Applies a security descriptor (ACL) to a file or directory.
    .Description
        Linux implementation of Set-Acl (Microsoft.PowerShell.Security).
        Applies the Owner, Group, and POSIX permission bits from an ACL object
        returned by Get-LinuxAcl, using 'chown' and 'chmod'.
        On Windows, delegates to the built-in Set-Acl.
        Alias: Set-Acl (for Microsoft.PowerShell.Security parity)

        Note: Requires sufficient privileges to change ownership (typically root/sudo).
              Permission bits can be changed by the file owner without elevated privileges.
    .Parameter Path
        Path of the file or directory to modify.
    .Parameter AclObject
        ACL object to apply. Accepts output from Get-LinuxAcl.
    .Parameter OctalMode
        Optional octal permission string (e.g. '644', '755'). Applied via chmod.
        If both AclObject and OctalMode are provided, OctalMode takes precedence for permissions.
    .Example
        # Copy permissions from one file to another
        $acl = Get-LinuxAcl /etc/hosts
        Set-LinuxAcl -Path /tmp/newfile -AclObject $acl
    .Example
        # Set mode directly
        Set-LinuxAcl -Path /tmp/script.sh -OctalMode '755'
    .Example
        # Pipeline: set same permissions on all files in a directory
        Get-ChildItem /srv/www | ForEach-Object {
            $acl = Get-LinuxAcl $_.FullName
            # ... modify $acl.OctalMode ...
            Set-LinuxAcl -Path $_.FullName -AclObject $acl
        }
    .Notes
        Free to use under GNU v3 Public License (https://choosealicense.com/licenses/gpl-3.0/)
        Author: Peppe Kerstens (NLD)
        Version: 0.1.0
        Date: 2026-05-08
    .Link
        https://learn.microsoft.com/powershell/module/microsoft.powershell.security/set-acl
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ByAclObject')]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Path,

        [Parameter(Position = 1, ParameterSetName = 'ByAclObject')]
        [PSObject]$AclObject,

        [Parameter(ParameterSetName = 'ByOctalMode')]
        [ValidatePattern('^[0-7]{3,4}$')]
        [string]$OctalMode
    )

    process {
        if (-not $IsLinux) {
            if ($PSCmdlet.ParameterSetName -eq 'ByAclObject') {
                Microsoft.PowerShell.Security\Set-Acl -Path $Path -AclObject $AclObject
            } else {
                Write-Warning "Set-LinuxAcl: -OctalMode is a Linux-only parameter. On Windows, use Set-Acl with an AclObject."
            }
            return
        }

        if (-not (Test-Path -LiteralPath $Path)) {
            Write-Error "Set-LinuxAcl: Path not found: $Path"
            return
        }

        $realPath = (Resolve-Path -LiteralPath $Path).Path

        if ($PSCmdlet.ParameterSetName -eq 'ByAclObject' -and $AclObject) {
            # Apply owner:group via chown
            if ($AclObject.Owner -and $AclObject.Group) {
                $ownerGroup = "$($AclObject.Owner):$($AclObject.Group)"
                if ($PSCmdlet.ShouldProcess($realPath, "chown $ownerGroup")) {
                    & chown $ownerGroup -- $realPath
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "Set-LinuxAcl: chown failed for '$realPath' (may require elevated privileges)."
                    }
                }
            }

            # Apply permission bits via chmod — prefer OctalMode from AclObject
            $mode = if ($OctalMode) { $OctalMode } elseif ($AclObject.OctalMode) { $AclObject.OctalMode } else { $null }
            if ($mode) {
                if ($PSCmdlet.ShouldProcess($realPath, "chmod $mode")) {
                    & chmod $mode -- $realPath
                    if ($LASTEXITCODE -ne 0) {
                        Write-Error "Set-LinuxAcl: chmod failed for '$realPath'."
                    }
                }
            }

            # If getfacl/setfacl available and AclObject has extended ACL entries, apply them
            if (Get-Command setfacl -ErrorAction SilentlyContinue) {
                $namedEntries = $AclObject.Access | Where-Object {
                    $_.EntryType -in @('user', 'group') -and
                    $_.IdentityReference -notin @($AclObject.Owner, $AclObject.Group, 'other')
                }
                foreach ($entry in $namedEntries) {
                    $spec = "$($entry.EntryType):$($entry.IdentityReference):$($entry.Permissions)"
                    if ($PSCmdlet.ShouldProcess($realPath, "setfacl -m $spec")) {
                        & setfacl -m $spec -- $realPath
                    }
                }
            }

        } elseif ($PSCmdlet.ParameterSetName -eq 'ByOctalMode') {
            if ($PSCmdlet.ShouldProcess($realPath, "chmod $OctalMode")) {
                & chmod $OctalMode -- $realPath
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "Set-LinuxAcl: chmod failed for '$realPath'."
                }
            }
        }
    }
}
