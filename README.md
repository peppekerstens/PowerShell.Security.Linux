# PowerShell.Security.Linux

PowerShell module providing Linux-native cmdlet parity with **Microsoft.PowerShell.Security**.  
Scripts written for Windows using `Get-Acl` / `Set-Acl` work on Linux without modification.

---

## What it does

`PowerShell.Security.Linux` wraps `stat`, `chmod`, `chown`, and optionally `getfacl`/`setfacl` to give PowerShell cmdlets that mirror Microsoft.PowerShell.Security.  
Functions use Linux-appropriate names; **Microsoft.PowerShell.Security aliases are included** so existing Windows scripts run unmodified.

| Linux-native cmdlet | Security alias | Status | Linux tool |
|---|---|---|---|
| `Get-LinuxAcl` | `Get-Acl` | ✅ Implemented | `stat`, optional `getfacl` |
| `Set-LinuxAcl` | `Set-Acl` | ✅ Implemented | `chmod`, `chown`, optional `setfacl` |
| `Get-AuthenticodeSignature` | _(same)_ | 🔧 Stub | — |
| `Set-AuthenticodeSignature` | _(same)_ | 🔧 Stub | — |
| `New-FileCatalog` | _(same)_ | 🔧 Stub | — |
| `Test-FileCatalog` | _(same)_ | 🔧 Stub | — |

The module is **Linux-only**. On Windows, `Get-LinuxAcl` and `Set-LinuxAcl` delegate to the built-in `Microsoft.PowerShell.Security\Get-Acl` and `Set-Acl`.

> **Note:** `getfacl`/`setfacl` are not installed by default on most distributions.  
> Install with: `sudo apt install acl`  
> The module works without them — extended ACL entries are simply omitted.

---

## Requirements

- PowerShell 7.2+
- Linux (any distribution with `stat`, `chmod`, `chown` in `$PATH`)
- Root or `sudo` privileges for `Set-LinuxAcl` ownership changes (`chown`)

---

## Installation

```powershell
# Clone the repository
git clone https://github.com/peppekerstens/PowerShell.Security.Linux.git

# Import the module
Import-Module ./PowerShell.Security.Linux/PowerShell.Security.Linux/PowerShell.Security.Linux.psd1
```

---

## Usage

```powershell
# Get permissions for a file (Linux-native name)
Get-LinuxAcl /etc/hosts

# Same call using the Microsoft.PowerShell.Security parity alias
Get-Acl /etc/hosts

# Get permissions including owner, group, and access entries
$acl = Get-LinuxAcl /etc/hosts
$acl.Owner
$acl.Group
$acl.UnixMode     # e.g. -rw-r--r--
$acl.OctalMode    # e.g. 644
$acl.Access       # array of access entries

# Pipeline input from Get-ChildItem
Get-ChildItem /etc | Get-LinuxAcl | Where-Object { $_.Owner -ne 'root' }

# Set permissions via octal mode
Set-LinuxAcl -Path /tmp/script.sh -OctalMode '755'

# Same via alias
Set-Acl -Path /tmp/script.sh -OctalMode '755'

# Copy permissions from one file to another
$acl = Get-LinuxAcl /etc/hosts
Set-LinuxAcl -Path /tmp/newfile -AclObject $acl

# WhatIf support
Set-LinuxAcl -Path /tmp/script.sh -OctalMode '600' -WhatIf
```

---

## Examples

See [`Examples\`](Examples/) for ready-to-run scripts:

| Script | Description |
|---|---|
| `Get-DirectoryPermissions.ps1` | List all file permissions in a directory |
| `Find-NonRootFiles.ps1` | Find files not owned by root |
| `Find-WorldWritable.ps1` | Find world-writable files (security audit) |
| `Copy-FilePermissions.ps1` | Copy permissions from one file to another |

---

## Cmdlet Status

### Fully Implemented

| Linux-native cmdlet | Alias | Parameters |
|---|---|---|
| `Get-LinuxAcl` | `Get-Acl` | `-Path` (wildcard, pipeline), `-LiteralPath` |
| `Set-LinuxAcl` | `Set-Acl` | `-Path`, `-AclObject`, `-OctalMode`, `-WhatIf` |

### Stubs (not yet implemented — PRs welcome)

| Cmdlet | Notes |
|---|---|
| `Get-AuthenticodeSignature` | Code signing not applicable on Linux |
| `Set-AuthenticodeSignature` | Code signing not applicable on Linux |
| `New-FileCatalog` | Catalog files are Windows-only |
| `Test-FileCatalog` | Catalog files are Windows-only |

---

## Implementation Notes

- `Get-LinuxAcl` uses `stat --format='%a|%A|%U|%G|%F|%n'` as primary tool — universally available on Linux
- If `getfacl` is installed, extended named user/group ACL entries are included in the `Access` array
- `Set-LinuxAcl` applies owner and group via `chown`, permissions via `chmod`
- If `setfacl` is installed, named ACL entries from the `AclObject` are also applied
- `Access` entries expose both a `Permissions` string (`rwx`, `r--`, etc.) and a `FileSystemRights` label (`FullControl`, `Modify`, `ReadAndExecute`, `Read`, `WriteAndExecute`, `Write`, `ExecuteFile`, `None`) matching Windows naming conventions
- `Set-LinuxAcl` supports `-WhatIf` via `[CmdletBinding(SupportsShouldProcess)]`
- On Windows, `Get-LinuxAcl` / `Set-LinuxAcl` delegate to `Microsoft.PowerShell.Security\Get-Acl` / `Set-Acl`
- The module throws a descriptive error if loaded directly on Windows (Linux-only guard in `.psm1`)
- Output objects use `[PSCustomObject]` with `PSTypeName = 'Security.Linux.FileAcl'`

---

## Version History

| Version | Date | Notes |
|---|---|---|
| 0.1.0 | 2026-05-08 | Initial release. Get-LinuxAcl and Set-LinuxAcl implemented. Stubs for Authenticode and catalog functions. |

---

## License

[GNU General Public License v3.0](LICENSE)
