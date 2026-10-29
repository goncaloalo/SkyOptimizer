. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')

Describe 'Exact startup contracts never execute command lines' {
    BeforeEach {
        $script:startupState=ConvertTo-SkyRegistryState -Exists $true -Kind String -Value '"C:\Fixture\Spotify.exe" --autostart --minimized'
        $script:signatureStatus='Valid';$script:publisher='Spotify AB';$script:product='Spotify'
    }
    Mock Get-SkyStartupContract {[pscustomobject]@{Path='C:\Fixture\Spotify.exe';Arguments='--autostart --minimized';Publishers=@('Spotify AB');Product='Spotify';Impact='manual start'}}
    Mock Get-SkyResourceState {$script:startupState}
    Mock Assert-SkyNoReparsePoint {}
    Mock Get-Item {[pscustomobject]@{VersionInfo=[pscustomobject]@{ProductName=$script:product;FileVersion='1.0'}}}
    Mock Get-AuthenticodeSignature {
        $certificate=New-Object psobject -Property @{Thumbprint='fixture-certificate'}
        $certificate | Add-Member ScriptMethod GetNameInfo {param($type,$issuer) $script:publisher}
        [pscustomobject]@{Status=$script:signatureStatus;SignerCertificate=$certificate}
    }
    Mock Get-FileHash {[pscustomobject]@{Hash='fixture-hash'}}
    Mock Invoke-SkyNativeProcess {throw 'No execution'}
    It 'admits only the fixed path arguments publisher and product' {
        (Get-SkyStartupCandidate Spotify).Status | Should Be Candidate
        $script:startupState=ConvertTo-SkyRegistryState -Exists $true -Kind String -Value 'cmd.exe /c Spotify.exe'
        (Get-SkyStartupCandidate Spotify).Status | Should Be Deferred
        Assert-MockCalled Invoke-SkyNativeProcess -Times 0 -Exactly -Scope It
    }
    It 'distinguishes absence, invalid signature and replaced product' {
        $script:signatureStatus='NotSigned';{Get-SkyStartupCandidate Spotify} | Should Throw
        $script:signatureStatus='Valid';$script:publisher='Untrusted';{Get-SkyStartupCandidate Spotify} | Should Throw
        $script:publisher='Spotify AB';$script:product='Other';{Get-SkyStartupCandidate Spotify} | Should Throw
        $script:startupState=ConvertTo-SkyRegistryState -Exists $false
        (Get-SkyStartupCandidate Spotify).Status | Should Be Absent
    }
}

Describe 'Startup deletion reuses exact registry baseline and external conflict protection' {
    BeforeEach {
        $Global:SkyBackupDir=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null=[IO.Directory]::CreateDirectory($Global:SkyBackupDir)
        $script:resource=ConvertTo-SkyRegistryResource 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' 'Spotify'
        $script:original=ConvertTo-SkyRegistryState -Exists $true -Kind ExpandString -Value '"%APPDATA%\Spotify\Spotify.exe" --autostart --minimized'
        $script:state=$script:original;$script:writes=0;$script:failAfter=$false;$script:failSave=$false;$script:hash='hash1'
    }
    Mock Get-SkyMachineId {'fixture-machine'}
    Mock Get-SkyUserSid {'fixture-user'}
    Mock Get-SkyResourceState {$script:state}
    Mock Set-SkyResourceState {$script:writes++;$script:state=$State;if($script:failAfter){throw 'after write'}}
    Mock Save-SkyMutationState {
        if($script:failSave){throw 'disk full'}
        Write-SkyAtomicFile -Path (Join-Path $BackupDirectory 'mutation_state.json') -Content ($State | ConvertTo-Json -Depth 15)
    }
    Mock Get-SkyStartupCandidate {
        if(-not $script:state.Exists){return [pscustomobject]@{Name='Spotify';Status='Absent'}}
        [pscustomobject]@{Name='Spotify';Status='Candidate';Resource=$script:resource;Before=$script:state;FileHash=$script:hash}
    }
    Mock Open-SkyRegistryBase {throw 'Real registry forbidden'}
    It 'applies twice without losing the literal original type and restores only the owned value' {
        $candidate=Get-SkyStartupCandidate Spotify
        (Disable-SkyStartupCandidate $candidate).Status | Should Be Applied
        (Disable-SkyStartupCandidate $candidate).Status | Should Be Deferred
        @((Read-SkyMutationState $Global:SkyBackupDir).Entries).Count | Should Be 1
        $null=Restore-SkyTrackedChanges $Global:SkyBackupDir
        (Test-SkyStateEqual $script:state $script:original) | Should Be $true
        $script:writes | Should Be 2
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir).Count | Should Be 0
    }
    It 'refuses a changed executable or caller-supplied resource before any mutation' {
        $candidate=Get-SkyStartupCandidate Spotify;$script:hash='hash2'
        (Disable-SkyStartupCandidate $candidate).Status | Should Be Deferred
        $script:writes | Should Be 0
        $candidate=Get-SkyStartupCandidate Spotify
        $candidate.Resource=ConvertTo-SkyRegistryResource 'HKLM:\Software\Wrong' 'Other'
        (Disable-SkyStartupCandidate $candidate).Status | Should Be Deferred
        $script:writes | Should Be 0
    }
    It 'does not modify startup when backup fails and recovers an interruption after deletion' {
        $candidate=Get-SkyStartupCandidate Spotify;$script:failSave=$true
        {Disable-SkyStartupCandidate $candidate} | Should Throw
        $script:writes | Should Be 0
        $script:failSave=$false;$script:failAfter=$true
        {Disable-SkyStartupCandidate $candidate} | Should Throw
        $script:failAfter=$false
        $null=Restore-SkyTrackedChanges $Global:SkyBackupDir
        (Test-SkyStateEqual $script:state $script:original) | Should Be $true
    }
    It 'preserves an application recreated or externally changed Run entry during Undo' {
        $null=Disable-SkyStartupCandidate (Get-SkyStartupCandidate Spotify)
        $script:state=ConvertTo-SkyRegistryState -Exists $true -Kind String -Value 'external registration'
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir)[0].Status | Should Be Failed
        $script:state.Data | Should Be 'external registration'
        $script:writes | Should Be 1
    }
}
