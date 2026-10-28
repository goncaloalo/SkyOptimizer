. (Join-Path $PSScriptRoot '..\integration\SkyValidationEvidence.ps1')

Describe 'Independent privacy-scoped validation evidence' {
    BeforeEach {
        $script:key = [byte[]](1..32)
        $script:hash = 'A' * 64
        $script:specs = @([pscustomobject]@{Id='R001';Type='Registry';Hive='CurrentUser';View='Registry64';Path='Software\PrivateUser';Name='Secret'})
        $script:state = [ordered]@{Exists=$true;Kind='String';Value='sensitive-original'}
        $script:failRead = $false
    }
    Mock Get-SkyEvidenceIdentity { @('private-machine','private-sid') }
    Mock Read-SkyEvidenceResource { if ($script:failRead) { throw 'private-path-error' }; $script:state }
    It 'exports neither identity, paths, values nor key and survives JSON roundtrip' {
        $a=Get-SkyValidationSnapshot $script:specs $script:key $script:hash Before
        $json=$a | ConvertTo-Json -Depth 20
        $json | Should Not Match 'sensitive-original|PrivateUser|Secret|private-machine|private-sid'
        (Compare-SkyValidationSnapshot $a ($json | ConvertFrom-Json)).Verdict | Should Be Equal
    }
    It 'detects changed type, content, absence and array ordering' {
        $a=Get-SkyValidationSnapshot $script:specs $script:key $script:hash Before
        foreach($state in @(@{Exists=$true;Kind='ExpandString';Value='sensitive-original'},@{Exists=$false},@{Exists=$true;Kind='String';Value='different'})) {
            $script:state=$state
            (Compare-SkyValidationSnapshot $a (Get-SkyValidationSnapshot $script:specs $script:key $script:hash AfterUndo)).Verdict | Should Be Changed
        }
        $script:state=[ordered]@{Exists=$true;Kind='MultiString';Value=@('a','b')}
        $a=Get-SkyValidationSnapshot $script:specs $script:key $script:hash Before
        $script:state=[ordered]@{Exists=$true;Kind='MultiString';Value=@('b','a')}
        (Compare-SkyValidationSnapshot $a (Get-SkyValidationSnapshot $script:specs $script:key $script:hash AfterUndo)).Verdict | Should Be Changed
    }
    It 'never treats two failed reads as equality and exports no exception' {
        $script:failRead=$true
        $a=Get-SkyValidationSnapshot $script:specs $script:key $script:hash Before
        (Compare-SkyValidationSnapshot $a $a).Verdict | Should Be Inconclusive
        ($a | ConvertTo-Json -Depth 20) | Should Not Match 'private-path-error'
    }
    It 'refuses changed scope, key, source or identity' {
        $a=Get-SkyValidationSnapshot $script:specs $script:key $script:hash Before
        foreach($field in @('KeyId','SourceSha256','IdentityDigest')) {
            $b=$a | ConvertTo-Json -Depth 20 | ConvertFrom-Json
            $b.$field='B'*64
            { Compare-SkyValidationSnapshot $a $b } | Should Throw
        }
        $script:specs[0].Name='Other'
        $b=Get-SkyValidationSnapshot $script:specs $script:key $script:hash AfterUndo
        { Compare-SkyValidationSnapshot $a $b } | Should Throw
    }
    It 'refuses missing coverage and duplicate or malformed entries' {
        $a=Get-SkyValidationSnapshot $script:specs $script:key $script:hash Before
        $b=$a | ConvertTo-Json -Depth 20 | ConvertFrom-Json
        $b.Entries=@()
        { Compare-SkyValidationSnapshot $a $b } | Should Throw
        $b.Entries=@($a.Entries[0],$a.Entries[0])
        { Compare-SkyValidationSnapshot $a $b } | Should Throw
        $b.Entries=@([pscustomobject]@{Id='R001';ScopeDigest='bad';Status='Observed';StateDigest='bad'})
        { Compare-SkyValidationSnapshot $a $b } | Should Throw
    }
    It 'validates all specifications before any Windows read' {
        { Get-SkyValidationSnapshot @($script:specs[0],$script:specs[0]) $script:key $script:hash Before } | Should Throw
        $bad=[pscustomobject]@{Id='R002';Type='Unsupported'}
        { Get-SkyValidationSnapshot @($script:specs[0],$bad) $script:key $script:hash Before } | Should Throw
        Assert-MockCalled Read-SkyEvidenceResource -Times 0 -Exactly -Scope It
        { Get-SkyValidationSnapshot @() $script:key $script:hash Before } | Should Throw
        { Get-SkyEvidenceDigest ([byte[]]@(1)) 'text' } | Should Throw
    }
    It 'ignores resource and specification property ordering but detects scope coverage differences' {
        $other=[pscustomobject]@{Id='R002';Type='Service';Name='Example'}
        $a=Get-SkyValidationSnapshot @($script:specs[0],$other) $script:key $script:hash Before
        $b=Get-SkyValidationSnapshot @($other,$script:specs[0]) $script:key $script:hash AfterUndo
        (Compare-SkyValidationSnapshot $a $b).Verdict | Should Be Equal
        $b=Get-SkyValidationSnapshot $script:specs $script:key $script:hash AfterUndo
        { Compare-SkyValidationSnapshot $a $b } | Should Throw
    }
}
