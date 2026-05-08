@{
    # PSScriptAnalyzer settings for Linux peer modules
    # Rules suppressed here are intentional design patterns, not code defects.
    ExcludeRules = @(
        # These modules deliberately override built-in cmdlets on Linux.
        'PSAvoidOverwritingBuiltInCmdlets',

        # Stub functions (Write-Warning only) intentionally omit ShouldProcess
        # because they do not change state — they only emit a not-supported warning.
        'PSUseShouldProcessForStateChangingFunctions',
        'PSShouldProcess',

        # Stub parameters exist for interface parity with Windows cmdlets.
        # They are not used in the Linux implementation by design.
        'PSReviewUnusedParameter',

        # Cross-platform UTF-8 without BOM is intentional.
        'PSUseBOMForUnicodeEncodedFile',

        # Test files intentionally call cmdlets with incomplete params to verify error behavior.
        'PSUseCmdletCorrectly'
    )
}
