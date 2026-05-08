#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.2.0' }
<#
.Synopsis
    Pester tests for PowerShell.Security.Linux example scripts.
.Description
    Validates that each example script in the Examples\ folder:
      - exists on disk
      - has no syntax errors (parses cleanly)
    Linux-only execution tests are guarded with -Skip:(-not $IsLinux).
    All tests run on Windows (syntax/structure checks); live execution
    tests are skipped on Windows.
.Notes
    Free to use under GNU v3 Public License (https://choosealicense.com/licenses/gpl-3.0/)
    Author: Peppe Kerstens (NLD)
    Run with: Invoke-Pester .\Examples.Tests.ps1 -Output Detailed
#>

BeforeDiscovery {
    $script:ExamplesDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $PSCommandPath -Parent }
    $script:ExampleFiles = @(
        'Get-DirectoryPermissions.ps1'
        'Find-NonRootFiles.ps1'
        'Find-WorldWritable.ps1'
        'Copy-FilePermissions.ps1'
    )
}

BeforeAll {
    $script:ExamplesDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $PSCommandPath -Parent }
    if ($IsLinux) {
        $modulePath = Join-Path (Split-Path $script:ExamplesDir -Parent) 'PowerShell.Security.Linux' 'PowerShell.Security.Linux.psd1'
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force -ErrorAction Stop
        }
    }
}

Describe 'Example script files exist' {
    It 'Examples directory contains <_>' -ForEach $script:ExampleFiles {
        Join-Path $script:ExamplesDir $_ | Should -Exist
    }
}

Describe 'Example scripts have no syntax errors' {
    It '<_> parses without errors' -ForEach $script:ExampleFiles {
        $filePath = Join-Path $script:ExamplesDir $_
        $errors   = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }
}

Describe 'Get-DirectoryPermissions' {
    It 'script file exists' {
        Join-Path $script:ExamplesDir 'Get-DirectoryPermissions.ps1' | Should -Exist
    }
    It 'Get-LinuxAcl returns objects for /etc files' -Skip:(-not $IsLinux) {
        $results = Get-ChildItem /etc -File -ErrorAction SilentlyContinue |
            Select-Object -First 5 | Get-LinuxAcl
        ($results | Measure-Object).Count | Should -BeGreaterOrEqual 1
        $results[0].PSObject.Properties.Name | Should -Contain 'Owner'
        $results[0].PSObject.Properties.Name | Should -Contain 'UnixMode'
    }
    It 'UnixMode starts with - or d or l' -Skip:(-not $IsLinux) {
        $results = Get-ChildItem /etc -ErrorAction SilentlyContinue |
            Select-Object -First 5 | Get-LinuxAcl
        foreach ($r in $results) {
            $r.UnixMode[0] | Should -BeIn @('-','d','l','c','b','p','s')
        }
    }
}

Describe 'Find-NonRootFiles' {
    It 'script file exists' {
        Join-Path $script:ExamplesDir 'Find-NonRootFiles.ps1' | Should -Exist
    }
    It 'Get-LinuxAcl Owner property is always populated' -Skip:(-not $IsLinux) {
        $results = Get-ChildItem /etc -File -ErrorAction SilentlyContinue |
            Select-Object -First 10 | Get-LinuxAcl
        foreach ($r in $results) {
            $r.Owner | Should -Not -BeNullOrEmpty
        }
    }
    It 'filtering by Owner works correctly' -Skip:(-not $IsLinux) {
        $nonRoot = Get-ChildItem /etc -File -ErrorAction SilentlyContinue |
            Get-LinuxAcl |
            Where-Object { $_.Owner -ne 'root' }
        # This might be empty — both outcomes are valid
        foreach ($r in $nonRoot) {
            $r.Owner | Should -Not -Be 'root'
        }
    }
}

Describe 'Find-WorldWritable' {
    It 'script file exists' {
        Join-Path $script:ExamplesDir 'Find-WorldWritable.ps1' | Should -Exist
    }
    It 'Access entries include an other entry' -Skip:(-not $IsLinux) {
        $acl = Get-LinuxAcl /etc/hosts
        $other = $acl.Access | Where-Object { $_.EntryType -eq 'other' }
        $other | Should -Not -BeNullOrEmpty
    }
    It 'other entry Permissions is 3 characters' -Skip:(-not $IsLinux) {
        $acl = Get-LinuxAcl /etc/hosts
        $other = $acl.Access | Where-Object { $_.EntryType -eq 'other' }
        $other.Permissions.Length | Should -Be 3
    }
    It 'world-writable filter logic catches a known writable path' -Skip:(-not $IsLinux) {
        # /tmp is typically drwxrwxrwt — other has 'w' bit
        $acl = Get-LinuxAcl /tmp
        $other = $acl.Access | Where-Object { $_.EntryType -eq 'other' }
        # /tmp should be world-writable (sticky bit still shows w in permissions)
        $other.Permissions[1] | Should -Be 'w'
    }
}

Describe 'Copy-FilePermissions' {
    It 'script file exists' {
        Join-Path $script:ExamplesDir 'Copy-FilePermissions.ps1' | Should -Exist
    }
    It 'Get-LinuxAcl / Set-LinuxAcl round-trip preserves OctalMode' -Skip:(-not $IsLinux) {
        $tmpFile = [System.IO.Path]::GetTempFileName()
        try {
            # Set a known mode
            Set-LinuxAcl -Path $tmpFile -OctalMode '644'
            $sourceAcl = Get-LinuxAcl /etc/hosts   # typically 644

            $target = [System.IO.Path]::GetTempFileName()
            try {
                Set-LinuxAcl -Path $target -AclObject $sourceAcl
                $result = Get-LinuxAcl $target
                $result.OctalMode | Should -Be $sourceAcl.OctalMode
            } finally {
                Remove-Item $target -ErrorAction SilentlyContinue
            }
        } finally {
            Remove-Item $tmpFile -ErrorAction SilentlyContinue
        }
    }
}
