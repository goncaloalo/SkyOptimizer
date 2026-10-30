. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')
Describe 'Exact launcher laboratory contract refuses unsupported identities' {
    BeforeEach {
        $script:context=[pscustomobject]@{Windows=[pscustomobject]@{Version='10.0.22631';BuildNumber=22631;ProductType=1;OperatingSystemSKU=48};DomainJoined=$false;MdmIndicator=$false;UserSid='fixture-user'}
        $script:state=ConvertTo-SkyRegistryState -Exists $true -Kind String -Value '"C:\Fixture\EpicGamesLauncher.exe" -silent'
        $script:signature='Valid';$script:product='EpicGamesLauncher';$script:publisher='Epic Games Inc.'
    }
    Mock Get-SkyMaxContext {$script:context}
    Mock Get-SkyLauncherStartupContract {[pscustomobject]@{Name=$Name;Status='Contract';Path='C:\Fixture\EpicGamesLauncher.exe';Arguments='-silent';Product='EpicGamesLauncher';Publishers=@('Epic Games Inc.');Reason='future login'}} -ParameterFilter {$Name -eq 'EpicGamesLauncher'}
    Mock Get-SkyResourceState {$script:state}
    Mock Assert-SkyNoReparsePoint {}
    Mock Get-Item {[pscustomobject]@{VersionInfo=[pscustomobject]@{ProductName=$script:product;FileVersion='1'}}}
    Mock Get-AuthenticodeSignature {
        $c=New-Object psobject -Property @{Thumbprint='fixture'}
        $c | Add-Member ScriptMethod GetNameInfo {param($t,$issuer) $script:publisher}
        [pscustomobject]@{Status=$script:signature;SignerCertificate=$c}
    }
    Mock Get-FileHash {[pscustomobject]@{Hash='fixture-hash'}}
    Mock Invoke-SkyNativeProcess {throw 'Never execute Run or binary'}
    It 'requires exact command and executable identity and stays out of automatic Apply' {
        $p=Get-SkyLauncherStartupPlan EpicGamesLauncher
        $p.Status | Should Be Candidate
        $p.AutomaticApplyAllowed | Should Be $false
        (Disable-SkyLauncherStartup $p).Status | Should Be Deferred
        $script:state=ConvertTo-SkyRegistryState -Exists $true -Kind String -Value 'cmd.exe /c EpicGamesLauncher.exe'
        (Get-SkyLauncherStartupPlan EpicGamesLauncher).Status | Should Be Deferred
        Assert-MockCalled Invoke-SkyNativeProcess -Times 0 -Exactly -Scope It
    }
    It 'does not mistake invalid signature, product or publisher for absence' {
        $script:signature='NotSigned';(Get-SkyLauncherStartupPlan EpicGamesLauncher).Status | Should Be Unknown
        $script:signature='Valid';$script:product='Other';(Get-SkyLauncherStartupPlan EpicGamesLauncher).Status | Should Be Unknown
        $script:product='EpicGamesLauncher';$script:publisher='Other';(Get-SkyLauncherStartupPlan EpicGamesLauncher).Status | Should Be Unknown
        $script:state=ConvertTo-SkyRegistryState -Exists $false
        (Get-SkyLauncherStartupPlan EpicGamesLauncher).Status | Should Be Absent
    }
    It 'refuses managed or unknown management before registry access' {
        $script:context.DomainJoined=$null
        (Get-SkyLauncherStartupPlan EpicGamesLauncher).Status | Should Be Deferred
        $script:context.DomainJoined=$true
        (Get-SkyLauncherStartupPlan EpicGamesLauncher).Status | Should Be Deferred
        Assert-MockCalled Get-SkyResourceState -Times 0 -Exactly -Scope It
    }
    It 'leaves Discord blocked without interpreting its updater chain' {
        (Get-SkyLauncherStartupPlan Discord).Status | Should Be Deferred
        Assert-MockCalled Get-SkyResourceState -Times 0 -Exactly -Scope It
    }
}

Describe 'Launcher lab reuses exact baseline and guarded Undo' {
    BeforeEach {
        $Global:SkyBackupDir=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null=[IO.Directory]::CreateDirectory($Global:SkyBackupDir)
        $script:resource=ConvertTo-SkyRegistryResource 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' EpicGamesLauncher
        $script:original=ConvertTo-SkyRegistryState -Exists $true -Kind ExpandString -Value '"%ProgramFiles(x86)%\Epic Games\Launcher.exe" -silent'
        $script:state=$script:original;$script:writes=0;$script:hash='one';$script:failSave=$false;$script:failAfter=$false
    }
    Mock Get-SkyMachineId {'fixture-machine'}
    Mock Get-SkyUserSid {'fixture-user'}
    Mock Get-SkyResourceState {$script:state}
    Mock Set-SkyResourceState {$script:writes++;$script:state=$State;if($script:failAfter){throw 'after deletion'}}
    Mock Get-SkyLauncherStartupPlan {
        [pscustomobject]@{Name='EpicGamesLauncher';Status=$(if($script:state.Exists){'Candidate'}else{'Absent'});Resource=$script:resource;Before=$script:state;FileHash=$script:hash}
    }
    Mock Save-SkyMutationState {
        if($script:failSave){throw 'backup failed'}
        Write-SkyAtomicFile -Path (Join-Path $BackupDirectory 'mutation_state.json') -Content ($State | ConvertTo-Json -Depth 15)
    }
    Mock Open-SkyRegistryBase {throw 'No real registry'}
    It 'preserves literal ExpandString baseline across repeated Apply then Undo' {
        $plan=Get-SkyLauncherStartupPlan EpicGamesLauncher
        (Disable-SkyLauncherStartup $plan -AllowUnvalidated).Status | Should Be Applied
        (Disable-SkyLauncherStartup $plan -AllowUnvalidated).Status | Should Be Deferred
        $null=Restore-SkyTrackedChanges $Global:SkyBackupDir
        (Test-SkyStateEqual $script:state $script:original) | Should Be $true
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir).Count | Should Be 0
    }
    It 'rejects identity drift or a forged resource before mutation' {
        $plan=Get-SkyLauncherStartupPlan EpicGamesLauncher;$script:hash='two'
        (Disable-SkyLauncherStartup $plan -AllowUnvalidated).Status | Should Be Deferred
        $plan=Get-SkyLauncherStartupPlan EpicGamesLauncher
        $plan.Resource=ConvertTo-SkyRegistryResource 'HKLM:\Software\Other' Value
        (Disable-SkyLauncherStartup $plan -AllowUnvalidated).Status | Should Be Deferred
        $script:writes | Should Be 0
    }
    It 'does not delete Run without durable backup and recovers an interruption' {
        $plan=Get-SkyLauncherStartupPlan EpicGamesLauncher;$script:failSave=$true
        {Disable-SkyLauncherStartup $plan -AllowUnvalidated} | Should Throw
        $script:writes | Should Be 0
        $script:failSave=$false;$script:failAfter=$true
        {Disable-SkyLauncherStartup $plan -AllowUnvalidated} | Should Throw
        $script:failAfter=$false;$null=Restore-SkyTrackedChanges $Global:SkyBackupDir
        (Test-SkyStateEqual $script:state $script:original) | Should Be $true
    }
    It 'preserves an externally recreated Run entry during Undo' {
        $null=Disable-SkyLauncherStartup (Get-SkyLauncherStartupPlan EpicGamesLauncher) -AllowUnvalidated
        $script:state=ConvertTo-SkyRegistryState -Exists $true -Kind String -Value 'external'
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir)[0].Status | Should Be Failed
        $script:state.Data | Should Be external
    }
}

Describe 'Background package expansion is a fixed laboratory identity catalogue' {
    It 'adds only explicit optional package families and preserves functional warnings' {
        $contracts=@(Get-SkyBackgroundFamilyContracts)
        $contracts.Count | Should Be 4
        @($contracts.PackageFamilyName | Select-Object -Unique).Count | Should Be 4
        @($contracts | Where-Object {$_.PackageFamilyName -match 'Store|Gaming|Xbox|VCLibs|Mail|Security'}).Count | Should Be 0
        ($contracts | Where-Object Role -eq PhoneLink).Impact | Should Match 'chamadas'
        ($contracts | Where-Object Role -eq FeedbackHub).Impact | Should Match 'diagnostico'
    }
}
