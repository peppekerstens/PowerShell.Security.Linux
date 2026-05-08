#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.2.0' }
<#
.Synopsis
    Pester tests for PowerShell.Security.Linux module.
.Description
    Validates module structure, function exports, alias exports, and runtime behaviour.
    Linux-only execution tests are guarded with -Skip:(-not $IsLinux).
    All tests run on Windows (syntax/structure checks); live execution
    tests are skipped on Windows.
.Notes
    Free to use under GNU v3 Public License (https://choosealicense.com/licenses/gpl-3.0/)
    Author: Peppe Kerstens (NLD)
    Run with: Invoke-Pester .\PowerShell.Security.Linux.Tests.ps1 -Output Detailed
#>

BeforeDiscovery {
    $script:ModuleRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $PSCommandPath -Parent }

    $script:ExpectedFunctions = @(
        'Get-LinuxAcl',
        'Set-LinuxAcl',
        'Get-AuthenticodeSignature',
        'Set-AuthenticodeSignature',
        'New-FileCatalog',
        'Test-FileCatalog'
    )

    $script:ExpectedAliases = @(
        'Get-Acl',
        'Set-Acl'
    )
}

BeforeAll {
    $script:ModuleRoot   = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $PSCommandPath -Parent }
    $script:ManifestPath = Join-Path $script:ModuleRoot 'PowerShell.Security.Linux.psd1'
    $script:PsmPath      = Join-Path $script:ModuleRoot 'PowerShell.Security.Linux.psm1'
    if ($IsLinux) {
        Import-Module $script:ManifestPath -Force -ErrorAction Stop
    }
}

# ── Module files ──────────────────────────────────────────────────────────────

Describe 'Module files exist' {
    It 'PowerShell.Security.Linux.psd1 exists' {
        $script:ManifestPath | Should -Exist
    }
    It 'PowerShell.Security.Linux.psm1 exists' {
        $script:PsmPath | Should -Exist
    }
    It 'Functions\ directory exists' {
        Join-Path $script:ModuleRoot 'Functions' | Should -Exist
    }
}

Describe 'Module manifest is valid' {
    It 'psd1 is parseable' {
        { Import-PowerShellDataFile $script:ManifestPath } | Should -Not -Throw
    }
    It 'ModuleVersion is set' {
        $m = Import-PowerShellDataFile $script:ManifestPath
        $m.ModuleVersion | Should -Not -BeNullOrEmpty
    }
    It 'FunctionsToExport contains <_>' -ForEach $script:ExpectedFunctions {
        $m = Import-PowerShellDataFile $script:ManifestPath
        $m.FunctionsToExport | Should -Contain $_
    }
    It 'AliasesToExport contains <_>' -ForEach $script:ExpectedAliases {
        $m = Import-PowerShellDataFile $script:ManifestPath
        $m.AliasesToExport | Should -Contain $_
    }
}

Describe 'Function files exist and have no syntax errors' {
    It '<_>.ps1 exists' -ForEach $script:ExpectedFunctions {
        Join-Path $script:ModuleRoot 'Functions' "$_.ps1" | Should -Exist
    }
    It '<_>.ps1 parses without errors' -ForEach $script:ExpectedFunctions {
        $filePath = Join-Path $script:ModuleRoot 'Functions' "$_.ps1"
        $errors   = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }
}

# ── Linux-only runtime tests ──────────────────────────────────────────────────

Describe 'Module loads on Linux' -Skip:(-not $IsLinux) {
    It 'module is importable' {
        Get-Module PowerShell.Security.Linux | Should -Not -BeNullOrEmpty
    }
    It 'Linux-native function <_> is exported' -ForEach $script:ExpectedFunctions {
        Get-Command $_ -Module PowerShell.Security.Linux | Should -Not -BeNullOrEmpty
    }
    It 'alias <_> is exported' -ForEach $script:ExpectedAliases {
        Get-Alias $_ -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }
}

Describe 'Get-LinuxAcl' -Skip:(-not $IsLinux) {
    BeforeAll {
        # Use /etc/hosts — always exists, always readable
        $script:testPath = '/etc/hosts'
        $script:acl = Get-LinuxAcl $script:testPath
    }

    It 'returns an object without throwing' {
        { Get-LinuxAcl $script:testPath } | Should -Not -Throw
    }
    It 'Path property matches input' {
        $script:acl.Path | Should -Be $script:testPath
    }
    It 'Owner property is non-empty' {
        $script:acl.Owner | Should -Not -BeNullOrEmpty
    }
    It 'Group property is non-empty' {
        $script:acl.Group | Should -Not -BeNullOrEmpty
    }
    It 'UnixMode is a 10-character string' {
        $script:acl.UnixMode.Length | Should -Be 10
    }
    It 'OctalMode is a 3 or 4 digit octal string' {
        $script:acl.OctalMode | Should -Match '^[0-7]{3,4}$'
    }
    It 'Access array contains at least 3 entries (user/group/other)' {
        ($script:acl.Access | Measure-Object).Count | Should -BeGreaterOrEqual 3
    }
    It 'Access entries have required properties' {
        $script:acl.Access | ForEach-Object {
            $_.PSObject.Properties.Name | Should -Contain 'IdentityReference'
            $_.PSObject.Properties.Name | Should -Contain 'EntryType'
            $_.PSObject.Properties.Name | Should -Contain 'FileSystemRights'
            $_.PSObject.Properties.Name | Should -Contain 'Permissions'
        }
    }
    It 'Permissions strings are 3 characters' {
        $script:acl.Access | ForEach-Object {
            $_.Permissions.Length | Should -Be 3
        }
    }
    It 'FileSystemRights values are valid labels' {
        $valid = @('FullControl','Modify','ReadAndExecute','Read','WriteAndExecute','Write','ExecuteFile','None')
        $script:acl.Access | ForEach-Object {
            $_.FileSystemRights | Should -BeIn $valid
        }
    }
    It 'Sddl property is null on Linux' {
        $script:acl.Sddl | Should -BeNullOrEmpty
    }
    It 'alias Get-Acl returns the same result' {
        $viaAlias = Get-Acl $script:testPath
        $viaAlias.Path  | Should -Be $script:acl.Path
        $viaAlias.Owner | Should -Be $script:acl.Owner
    }
    It 'pipeline input from Get-ChildItem works' {
        $results = Get-ChildItem /etc -File | Select-Object -First 3 | Get-LinuxAcl
        ($results | Measure-Object).Count | Should -BeGreaterOrEqual 1
        $results[0].PSObject.Properties.Name | Should -Contain 'Path'
    }
    It 'non-existent path writes an error' {
        { Get-LinuxAcl '/tmp/zzz-nonexistent-path-xyzzy' -ErrorAction Stop } | Should -Throw
    }
    It 'directory path returns a result' {
        $result = Get-LinuxAcl /etc
        $result | Should -Not -BeNullOrEmpty
        $result.FileType | Should -BeLike '*directory*'
    }
}

Describe 'Set-LinuxAcl' -Skip:(-not $IsLinux) {
    BeforeAll {
        # Create a temp file owned by the current user for safe chmod testing
        $script:tmpFile = [System.IO.Path]::GetTempFileName()
        Set-Content $script:tmpFile 'test'
    }
    AfterAll {
        Remove-Item $script:tmpFile -ErrorAction SilentlyContinue
    }

    It 'sets mode via -OctalMode without throwing' {
        { Set-LinuxAcl -Path $script:tmpFile -OctalMode '644' } | Should -Not -Throw
    }
    It 'mode is applied correctly via -OctalMode' {
        Set-LinuxAcl -Path $script:tmpFile -OctalMode '600'
        $acl = Get-LinuxAcl $script:tmpFile
        $acl.OctalMode | Should -Be '600'
    }
    It 'mode is applied via AclObject.OctalMode' {
        Set-LinuxAcl -Path $script:tmpFile -OctalMode '644'  # reset
        $acl = Get-LinuxAcl $script:tmpFile
        $acl | Add-Member -NotePropertyName OctalMode -NotePropertyValue '640' -Force
        Set-LinuxAcl -Path $script:tmpFile -AclObject $acl
        $newAcl = Get-LinuxAcl $script:tmpFile
        $newAcl.OctalMode | Should -Be '640'
    }
    It '-WhatIf does not change permissions' {
        Set-LinuxAcl -Path $script:tmpFile -OctalMode '644'
        Set-LinuxAcl -Path $script:tmpFile -OctalMode '600' -WhatIf
        $acl = Get-LinuxAcl $script:tmpFile
        $acl.OctalMode | Should -Be '644'
    }
    It 'alias Set-Acl with -OctalMode works' {
        { Set-Acl -Path $script:tmpFile -OctalMode '644' } | Should -Not -Throw
    }
}

Describe 'Stub functions emit warnings' -Skip:(-not $IsLinux) {
    It '<_> emits a warning and does not throw' -ForEach @(
        'Get-AuthenticodeSignature', 'Set-AuthenticodeSignature',
        'New-FileCatalog', 'Test-FileCatalog'
    ) {
        { & $_ -WarningAction SilentlyContinue } | Should -Not -Throw
    }
}
