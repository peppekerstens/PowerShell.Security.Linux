# PowerShell.Security.Linux

[![Pester Tests](https://github.com/peppekerstens/PowerShell.Security.Linux/actions/workflows/pester.yml/badge.svg)](https://github.com/peppekerstens/PowerShell.Security.Linux/actions/workflows/pester.yml)

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

## CI / Testing

Tested across 5 Linux distributions in containers:

| Distro | Image |
|---|---|
| Ubuntu 24.04 | `ghcr.io/peppekerstens/testinfra:ubuntu-24.04` |
| Debian 12 | `ghcr.io/peppekerstens/testinfra:debian-12` |
| Fedora 40 | `ghcr.io/peppekerstens/testinfra:fedora-40` |
| openSUSE Tumbleweed | `ghcr.io/peppekerstens/testinfra:opensuse-tumbleweed` |
| Arch Linux | `ghcr.io/peppekerstens/testinfra:arch-latest` |

Run locally with:

```powershell
# From the repo root
docker compose -f docker-compose.test.yml up --abort-on-container-exit
```

GitHub Actions runs the same matrix on every push — see `.github/workflows/pester.yml`.
---

## Version history

| Version | Date | Notes |
|---|---|---|
| 0.1.0 | 2026-05-08 | Initial release. Get-LinuxAcl and Set-LinuxAcl implemented. Stubs for Authenticode and catalog functions. |

---

## How we built this

### Why this module exists

`Get-Acl` and `Set-Acl` are used constantly in Windows automation — checking file permissions, auditing access, copying ACLs between files. On Linux, PS7.5 native `Get-Acl` returns something, but it's pretty useless: it gives you a generic object with almost no properties populated, certainly not the rich `FileSecurity` object you get on Windows. The gap is real. `PowerShell.Security.Linux` fills it with Linux-native permission data shaped to match the Windows API.

### Tool choices

**`stat --format='%a|%A|%U|%G|%F|%n'`** is the primary tool. `stat` is universally available on any Linux — no optional packages needed. The format string extracts octal mode (`%a`), symbolic mode (`%A`), owner (`%U`), group (`%G`), file type (`%F`), and filename (`%n`) in one call. This gives us everything we need without parsing `ls -la` output, which is fragile.

**`getfacl` / `setfacl`** are optional. They provide extended POSIX ACL entries (named user, named group). The module detects at runtime whether `getfacl` is installed and, if it is, enriches the `Access` array with named entries. If not, the basic owner/group/other permissions are still returned. This way the module works on any Linux without requiring the `acl` package.

**`chmod` and `chown`** handle writes. Standard, universal, nothing surprising there.

### Key gotchas

**PSPath provider prefix.** When `Get-ChildItem` pipes objects into `Get-LinuxAcl`, the `PSPath` property of each file object includes the PowerShell provider prefix: `Microsoft.PowerShell.Core\FileSystem::/etc/hosts`. If you pass that directly to `stat`, it fails — `stat` wants a real path, not a PS provider path. The fix strips the provider prefix before passing the path to any Linux tool.

**POSIX permissions → Windows FileSystemRights mapping.** The `Access` entries need a `FileSystemRights` label that means something to someone used to Windows. The mapping is: `rwx` → `FullControl`, `rw-` → `Modify`, `r-x` → `ReadAndExecute`, `r--` → `Read`, `-wx` → `WriteAndExecute`, `-w-` → `Write`, `--x` → `ExecuteFile`, `---` → `None`. It's an approximation — POSIX and Windows ACL models are not equivalent — but it's close enough to be useful.

**`stat` vs `getfacl` for "who has access".** `stat` gives you the classic Unix trinity (owner, group, other). `getfacl` gives you all named ACL entries. When both are available, `Get-LinuxAcl` merges them: the `stat` output provides the base entries, and `getfacl` adds any additional named user/group entries. Without `getfacl`, only the three base entries appear.

**`SupportsShouldProcess` for Set.** `Set-LinuxAcl` runs `chmod` and `chown` which are destructive. Adding `[CmdletBinding(SupportsShouldProcess)]` and checking `$PSCmdlet.ShouldProcess(...)` before each call gives you proper `-WhatIf` and `-Confirm` support. This was a requirement from the start — changing permissions is exactly the kind of thing you want to dry-run first.

### Test approach

Tests use Pester 5.2+ with `BeforeDiscovery` platform detection. On Windows, all blocks skip. On WSL2, the full suite runs against real files in `/tmp`. Tests cover: basic `Get-LinuxAcl` output structure, pipeline input from `Get-ChildItem`, PSPath provider prefix stripping, `Set-LinuxAcl` with `-OctalMode`, `-WhatIf` behavior, and ACL copy via `-AclObject`. Examples are tested via `Examples\Examples.Tests.ps1`.

---

## License

[GNU General Public License v3.0](LICENSE)
