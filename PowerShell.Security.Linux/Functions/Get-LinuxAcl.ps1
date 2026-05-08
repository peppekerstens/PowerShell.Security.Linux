function Get-LinuxAcl {
    <#
    .Synopsis
        Gets the security descriptor (ACL) for a file or directory.
    .Description
        Linux implementation of Get-Acl (Microsoft.PowerShell.Security).
        Uses 'stat' (universally available) to read POSIX permission bits, owner,
        and group. If 'getfacl' is available (apt install acl), extended ACL entries
        are also included in the Access array.
        On Windows, delegates to the built-in Get-Acl.
        Alias: Get-Acl (for Microsoft.PowerShell.Security parity)
    .Parameter Path
        Path to the file or directory. Accepts pipeline input and wildcards.
    .Parameter LiteralPath
        Literal path — no wildcard expansion.
    .Example
        Get-LinuxAcl /etc/hosts
    .Example
        Get-LinuxAcl /var/log | Select-Object Path, Owner, Group, UnixMode
    .Example
        Get-ChildItem /etc | Get-LinuxAcl | Where-Object { $_.Owner -ne 'root' }
    .Notes
        Free to use under GNU v3 Public License (https://choosealicense.com/licenses/gpl-3.0/)
        Author: Peppe Kerstens (NLD)
        Version: 0.1.0
        Date: 2026-05-08
    .Link
        https://learn.microsoft.com/powershell/module/microsoft.powershell.security/get-acl
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByPath')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Position = 0, Mandatory, ParameterSetName = 'ByPath',
                   ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [string[]]$Path,

        [Parameter(Mandatory, ParameterSetName = 'ByLiteralPath',
                   ValueFromPipelineByPropertyName)]
        [Alias('PSPath')]
        [string[]]$LiteralPath
    )

    begin {
        if (-not $IsLinux) {
            # On Windows delegate to built-in Get-Acl
            return
        }

        # Check for getfacl (optional — provides extended ACL entries)
        $script:_hasGetfacl = [bool](Get-Command getfacl -ErrorAction SilentlyContinue)
    }

    process {
        if (-not $IsLinux) {
            $PSBoundParameters.Remove('Path') | Out-Null
            $PSBoundParameters.Remove('LiteralPath') | Out-Null
            if ($PSCmdlet.ParameterSetName -eq 'ByPath') {
                Microsoft.PowerShell.Security\Get-Acl -Path $Path @PSBoundParameters
            } else {
                Microsoft.PowerShell.Security\Get-Acl -LiteralPath $LiteralPath @PSBoundParameters
            }
            return
        }

        # Resolve paths
        $resolvedPaths = if ($PSCmdlet.ParameterSetName -eq 'ByLiteralPath') {
            # Strip PowerShell provider prefix (e.g. "Microsoft.PowerShell.Core\FileSystem::")
            # that arrives when Get-ChildItem pipeline objects bind via PSPath alias
            $LiteralPath | ForEach-Object {
                if ($_ -match '^[^:]+::[^:]+::(.+)$') { $Matches[1] }
                elseif ($_ -match '^Microsoft\.PowerShell\.Core\\FileSystem::(.+)$') { $Matches[1] }
                else { $_ }
            }
        } else {
            foreach ($p in $Path) {
                # Expand pipeline objects that carry FullName (e.g. FileInfo)
                if ($p -match '[*?]') {
                    Resolve-Path $p -ErrorAction SilentlyContinue | ForEach-Object { $_.Path }
                } else {
                    $p
                }
            }
        }

        foreach ($filePath in $resolvedPaths) {
            if (-not (Test-Path -LiteralPath $filePath)) {
                Write-Error "Get-LinuxAcl: Path not found: $filePath"
                continue
            }

            $realPath = (Resolve-Path -LiteralPath $filePath).Path

            # stat --format: octalmode|symbolicmode|owner|group|filetype|path
            $statOut = stat --format='%a|%A|%U|%G|%F|%n' -- $realPath 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Get-LinuxAcl: stat failed for '$realPath': $statOut"
                continue
            }

            $parts = $statOut -split '\|', 6
            if ($parts.Count -lt 6) {
                Write-Error "Get-LinuxAcl: Unexpected stat output for '$realPath': $statOut"
                continue
            }

            $octal    = $parts[0]
            $symbolic = $parts[1]   # e.g. -rw-r--r--
            $owner    = $parts[2]
            $group    = $parts[3]
            $fileType = $parts[4]

            # Parse symbolic mode into owner/group/other permission strings
            # symbolic is 10 chars: type + uuu + ggg + ooo
            $ownerBits = $symbolic.Substring(1, 3)  # positions 1-3
            $groupBits = $symbolic.Substring(4, 3)  # positions 4-6
            $otherBits = $symbolic.Substring(7, 3)  # positions 7-9

            # Build basic POSIX Access entries
            $access = @(
                [PSCustomObject]@{
                    IdentityReference = $owner
                    EntryType         = 'user'
                    FileSystemRights  = ConvertFrom-PosixBits $ownerBits
                    AccessControlType = 'Allow'
                    Permissions       = $ownerBits
                    IsInherited       = $false
                }
                [PSCustomObject]@{
                    IdentityReference = $group
                    EntryType         = 'group'
                    FileSystemRights  = ConvertFrom-PosixBits $groupBits
                    AccessControlType = 'Allow'
                    Permissions       = $groupBits
                    IsInherited       = $false
                }
                [PSCustomObject]@{
                    IdentityReference = 'other'
                    EntryType         = 'other'
                    FileSystemRights  = ConvertFrom-PosixBits $otherBits
                    AccessControlType = 'Allow'
                    Permissions       = $otherBits
                    IsInherited       = $false
                }
            )

            # If getfacl is available, add extended ACL entries (named user/group entries)
            if ($script:_hasGetfacl) {
                $faclOut = getfacl --omit-header --absolute-names -- $realPath 2>/dev/null
                foreach ($line in $faclOut) {
                    # named user:  user:www-data:r--
                    # named group: group:devs:rw-
                    if ($line -match '^(user|group):([^:]+):([rwx-]{3})$') {
                        $entryType = $Matches[1]
                        $identity  = $Matches[2]
                        $perms     = $Matches[3]
                        # Skip the unnamed owner/group entries — already included above
                        if ($identity -eq '') { continue }
                        $access += [PSCustomObject]@{
                            IdentityReference = $identity
                            EntryType         = $entryType
                            FileSystemRights  = ConvertFrom-PosixBits $perms
                            AccessControlType = 'Allow'
                            Permissions       = $perms
                            IsInherited       = $false
                        }
                    }
                }
            }

            [PSCustomObject]@{
                PSTypeName = 'Security.Linux.FileAcl'
                Path       = $realPath
                Owner      = $owner
                Group      = $group
                Access     = $access
                UnixMode   = $symbolic
                OctalMode  = $octal
                FileType   = $fileType
                Sddl       = $null
            }
        }
    }
}

# Helper: map POSIX permission string (e.g. 'rw-') to a Windows-style rights label
function ConvertFrom-PosixBits {
    param([string]$bits)
    $r = $bits[0] -ne '-'
    $w = $bits[1] -ne '-'
    $x = $bits[2] -ne '-'
    switch ("$([int]$r)$([int]$w)$([int]$x)") {
        '111' { return 'FullControl' }
        '110' { return 'Modify' }
        '101' { return 'ReadAndExecute' }
        '100' { return 'Read' }
        '011' { return 'WriteAndExecute' }
        '010' { return 'Write' }
        '001' { return 'ExecuteFile' }
        default { return 'None' }
    }
}
