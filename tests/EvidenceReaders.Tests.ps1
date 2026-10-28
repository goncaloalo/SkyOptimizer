. (Join-Path $PSScriptRoot '..\integration\SkyValidationEvidence.ps1')

Describe 'Independent registry reader contract without registry access' {
    BeforeEach {
        $script:exists=$true; $script:kind='ExpandString'; $script:value='%USERPROFILE%\private'
        $script:keyDisposed=$false; $script:rootDisposed=$false
        $script:fakeKey=New-Object PSObject
        $script:fakeKey | Add-Member ScriptMethod GetValueNames { if($script:exists){@('Value')}else{@()} }
        $script:fakeKey | Add-Member ScriptMethod GetValueKind { $script:kind }
        $script:fakeKey | Add-Member ScriptMethod GetValue { param($name,$default,$options)
            if($options -ne [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames){throw 'Expansion forbidden'}
            $script:value
        }
        $script:fakeKey | Add-Member ScriptMethod Dispose { $script:keyDisposed=$true }
        $script:fakeRoot=New-Object PSObject
        $script:fakeRoot | Add-Member ScriptMethod OpenSubKey { param($path,$writable)
            if($writable){throw 'Write access forbidden'}; $script:fakeKey
        }
        $script:fakeRoot | Add-Member ScriptMethod Dispose { $script:rootDisposed=$true }
        $script:spec=[pscustomobject]@{Type='Registry';Hive='CurrentUser';View='Registry64';Path='Software\Fake';Name='Value'}
    }
    Mock Open-SkyEvidenceRegistryRoot { $script:fakeRoot }
    It 'preserves existence, kind and literal expandable content and closes handles' {
        $r=Read-SkyEvidenceResource $script:spec
        $r.Exists | Should Be $true
        $r.Kind | Should Be ExpandString
        $r.Value | Should Be '%USERPROFILE%\private'
        $script:keyDisposed | Should Be $true
        $script:rootDisposed | Should Be $true
    }
    It 'distinguishes absence and refuses unsupported kinds while closing handles' {
        $script:exists=$false
        (Read-SkyEvidenceResource $script:spec).Exists | Should Be $false
        $script:exists=$true; $script:kind='None'
        { Read-SkyEvidenceResource $script:spec } | Should Throw
        $script:keyDisposed | Should Be $true
        $script:rootDisposed | Should Be $true
    }
    It 'refuses invalid hives without opening any handle' {
        $script:spec.Hive='Other'
        { Read-SkyEvidenceResource $script:spec } | Should Throw
        Assert-MockCalled Open-SkyEvidenceRegistryRoot -Times 0 -Exactly -Scope It
    }
}
