#
# Module manifest for module 'PowerShell.Security.Linux'
#

@{
    RootModule        = 'PowerShell.Security.Linux.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'c3d4e5f6-a7b8-9012-cdef-012345678902'
    Author            = 'Peppe Kerstens'
    CompanyName       = ''
    Copyright         = '(c) Peppe Kerstens. GPL-3.0 license.'
    Description       = 'PowerShell module for Linux providing cmdlet parity with Microsoft.PowerShell.Security. Implements Get-LinuxAcl and Set-LinuxAcl using stat, chmod, chown and optional getfacl/setfacl.'
    PowerShellVersion = '7.2'
    RequiredModules   = @()

    FunctionsToExport = @(
        # Fully implemented — Linux-native names
        'Get-LinuxAcl',
        'Set-LinuxAcl',
        # Stubs
        'Get-AuthenticodeSignature',
        'Set-AuthenticodeSignature',
        'New-FileCatalog',
        'Test-FileCatalog'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()

    # Microsoft.PowerShell.Security compatibility aliases
    AliasesToExport   = @(
        'Get-Acl',
        'Set-Acl'
    )

    PrivateData = @{
        PSData = @{
            Tags         = @('Linux', 'Security', 'ACL', 'Permissions', 'chmod', 'chown', 'getfacl', 'CrossPlatform')
            LicenseUri   = 'https://github.com/peppekerstens/PowerShell.Security.Linux/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/peppekerstens/PowerShell.Security.Linux'
            ReleaseNotes = @'
0.1.0 - Initial release. Get-LinuxAcl (stat + optional getfacl) and Set-LinuxAcl (chmod + chown) implemented. Stubs for Get-AuthenticodeSignature, Set-AuthenticodeSignature, New-FileCatalog, Test-FileCatalog.
'@
        }
    }
}
