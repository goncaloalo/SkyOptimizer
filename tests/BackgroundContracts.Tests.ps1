. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')
Describe 'Selective per-app background contract without Windows writes' {
    BeforeEach {
        Mock Get-AppxPackage {$script:packages}
            $script:context=[pscustomobject]@{Windows=[pscustomobject]@{Version='10.0.22631';BuildNumber=22631;ProductType=1;OperatingSystemSKU=48};DomainJoined=$false;MdmIndicator=$false}
        $script:packages=@([pscustomobject]@{PackageFamilyName='Microsoft.BingNews_8wekyb3d8bbwe';PackageFullName='Microsoft.BingNews_1_x64_8wekyb3d8bbwe';Version='1';PublisherId='8wekyb3d8bbwe';IsFramework=$false;IsResourcePackage=$false;NonRemovable=$false;Dependencies=@()})
        $script:states=@{};$script:writes=0;$script:failSave=$false;$script:failAfter=$false
        $Global:SkyBackupDir=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null=[IO.Directory]::CreateDirectory($Global:SkyBackupDir)
    }
    Mock Get-SkyMaxContext {$script:context}
    Mock Get-SkyResourceState {if($script:states.ContainsKey($Resource.Name)){$script:states[$Resource.Name]}else{ConvertTo-SkyRegistryState -Exists $false}}
    Mock Set-SkyResourceState {$script:writes++;$script:states[$Resource.Name]=$State;if($script:failAfter){throw 'interrupted after write'}}
    Mock Get-SkyMachineId {'fixture-machine'}
    Mock Get-SkyUserSid {'fixture-user'}
    Mock Save-SkyMutationState {
        if($script:failSave){throw 'backup unavailable'}
        Write-SkyAtomicFile -Path (Join-Path $BackupDirectory 'mutation_state.json') -Content ($State | ConvertTo-Json -Depth 15)
    }
    Mock Open-SkyRegistryBase {throw 'No live registry'}
    It 'proposes only allowlisted current-user packages and stays out of automatic Apply' {
        $script:packages += [pscustomobject]@{PackageFamilyName='Microsoft.WindowsStore_8wekyb3d8bbwe'}
        $p=Get-SkyBackgroundPlan
        $p.Status | Should Be Candidate
        $p.FamilyNames.Count | Should Be 1
        $p.AutomaticApplyAllowed | Should Be $false
        (Disable-SkySelectiveBackground $p).Status | Should Be Deferred
        $script:writes | Should Be 0
    }
    It 'refuses unsupported or unknown management without treating it as an unmanaged PC' {
        $script:context.DomainJoined=$null
        (Get-SkyBackgroundPlan).Status | Should Be Deferred
        $script:context.DomainJoined=$true
        (Get-SkyBackgroundPlan).Status | Should Be Deferred
        $script:context.DomainJoined=$false;$script:context.Windows.OperatingSystemSKU=101
        (Get-SkyBackgroundPlan).Status | Should Be Deferred
    }
    It 'keeps protected or incomplete package metadata out of the contract' {
        $script:packages[0].NonRemovable=$true
        (Get-SkyBackgroundPlan).Status | Should Be Deferred
        $script:packages[0].NonRemovable=$false;$script:packages[0].Dependencies=@([pscustomobject]@{Name='unresolved'})
        (Get-SkyBackgroundPlan).Status | Should Be Deferred
        $script:packages[0].Dependencies=@();$script:packages[0].PublisherId='other'
        (Get-SkyBackgroundPlan).Status | Should Be Deferred
    }
    It 'distinguishes absent packages, read failures and unsupported registry types' {
        $script:packages=@();(Get-SkyBackgroundPlan).Status | Should Be Absent
        Mock Get-AppxPackage {throw 'denied'}
        (Get-SkyBackgroundPlan).Status | Should Be Unknown
    }
    It 'does not override ForceAllow or UserInControl for a selected family' {
        foreach($name in @('LetAppsRunInBackground_ForceAllowTheseApps','LetAppsRunInBackground_UserInControlOfTheseApps')) {
            $script:states=@{};$script:states[$name]=ConvertTo-SkyRegistryState -Exists $true -Kind MultiString -Value @('Microsoft.BingNews_8wekyb3d8bbwe')
            (Get-SkyBackgroundPlan).Status | Should Be Deferred
        }
    }
    It 'refuses unknown list types and preserves global policy and unrelated list entries' {
        $script:states['LetAppsRunInBackground_ForceDenyTheseApps']=ConvertTo-SkyRegistryState -Exists $true -Kind String -Value 'external'
        (Get-SkyBackgroundPlan).Status | Should Be Unknown
        $script:states['LetAppsRunInBackground_ForceDenyTheseApps']=ConvertTo-SkyRegistryState -Exists $true -Kind MultiString -Value @('external','external','Other')
        $script:states['LetAppsRunInBackground']=ConvertTo-SkyRegistryState -Exists $true -Kind DWord -Value 1
        $p=Get-SkyBackgroundPlan
        $p.Status | Should Be Candidate
        (($p.Desired.Data)[0..2] -join ',') | Should Be 'external,external,Other'
        (Disable-SkySelectiveBackground $p -AllowUnvalidated).Status | Should Be Applied
        $script:states['LetAppsRunInBackground'].Data | Should Be '1'
        $null=Restore-SkyTrackedChanges $Global:SkyBackupDir
        ($script:states['LetAppsRunInBackground_ForceDenyTheseApps'].Data -join ',') | Should Be 'external,external,Other'
    }
    It 'keeps absence baseline through repeated Apply and restores only the owned value' {
        (Disable-SkySelectiveBackground (Get-SkyBackgroundPlan) -AllowUnvalidated).Status | Should Be Applied
        (Disable-SkySelectiveBackground (Get-SkyBackgroundPlan) -AllowUnvalidated).Status | Should Be AlreadyCompliant
        @((Read-SkyMutationState $Global:SkyBackupDir).Entries).Count | Should Be 1
        $null=Restore-SkyTrackedChanges $Global:SkyBackupDir
        $script:states['LetAppsRunInBackground_ForceDenyTheseApps'].Exists | Should Be $false
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir).Count | Should Be 0
        $script:writes | Should Be 2
    }
    It 'revalidates metadata, lists and caller-supplied desired state before any write' {
        $p=Get-SkyBackgroundPlan;$p.Desired.Data=@('forged')
        (Disable-SkySelectiveBackground $p -AllowUnvalidated).Status | Should Be Deferred
        $p=Get-SkyBackgroundPlan;$script:states['LetAppsRunInBackground_ForceAllowTheseApps']=ConvertTo-SkyRegistryState -Exists $true -Kind MultiString -Value @('external')
        (Disable-SkySelectiveBackground $p -AllowUnvalidated).Status | Should Be Deferred
        $script:writes | Should Be 0
    }
    It 'does not write without durable backup and can undo interruption after the write' {
        $p=Get-SkyBackgroundPlan;$script:failSave=$true
        {Disable-SkySelectiveBackground $p -AllowUnvalidated} | Should Throw
        $script:writes | Should Be 0
        $script:failSave=$false;$script:failAfter=$true
        {Disable-SkySelectiveBackground $p -AllowUnvalidated} | Should Throw
        $script:failAfter=$false;$null=Restore-SkyTrackedChanges $Global:SkyBackupDir
        $script:states['LetAppsRunInBackground_ForceDenyTheseApps'].Exists | Should Be $false
    }
    It 'preserves external changes on Undo instead of deleting them' {
        $null=Disable-SkySelectiveBackground (Get-SkyBackgroundPlan) -AllowUnvalidated
        $script:states['LetAppsRunInBackground_ForceDenyTheseApps']=ConvertTo-SkyRegistryState -Exists $true -Kind MultiString -Value @('externally changed')
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir)[0].Status | Should Be Failed
        $script:states['LetAppsRunInBackground_ForceDenyTheseApps'].Data[0] | Should Be 'externally changed'
    }
}

Describe 'Background laboratory operator lifecycle' {
    Mock New-SkyProtectedDirectory { $null=[IO.Directory]::CreateDirectory($Path) }
    Mock Assert-SkyNoReparsePoint {}
    BeforeEach {$Profile='Laboratory';$ExperimentalActions='';$Global:SkyBackupDir=$TestDrive;$script:answer='N';$script:status='Applied'}
    Mock Get-SkyBackgroundPlan {[pscustomobject]@{Status='Candidate';Reason='Synthetic plan';FamilyNames=@('fixture')}}
    Mock Write-SkyAtomicFile {}
    Mock Write-Host {}
    Mock Read-Host {$script:answer}
    Mock Disable-SkySelectiveBackground {New-SkyActionResult -Status $script:status -Reason synthetic -RestartRequired Yes}
    It 'rejects non-laboratory profile or unrelated actions' {
        $Profile='MAX';{Invoke-SkyBackgroundLab} | Should Throw
        $Profile='Laboratory';$ExperimentalActions='79';{Invoke-SkyBackgroundLab} | Should Throw
        Assert-MockCalled Disable-SkySelectiveBackground -Times 0 -Exactly -Scope It
    }
    It 'does not mutate after declined functional impact' {
        Invoke-SkyBackgroundLab
        $script:SkyLastExitCode | Should Be 2
        Assert-MockCalled Disable-SkySelectiveBackground -Times 0 -Exactly -Scope It
    }
    It 'routes approved write through guarded contract but keeps functional validation pending' {
        $script:answer='S';Invoke-SkyBackgroundLab
        $script:SkyLastExitCode | Should Be 2
        Assert-MockCalled Disable-SkySelectiveBackground -Times 1 -Exactly -Scope It -ParameterFilter {$AllowUnvalidated}
    }
    It 'communicates failed write and records the result' {
        $script:answer='S';$script:status='Failed';Invoke-SkyBackgroundLab
        $script:SkyLastExitCode | Should Be 1
        Assert-MockCalled Write-SkyAtomicFile -Times 1 -Exactly -Scope It -ParameterFilter {$Path -like '*background_lab_result.json'}
    }
}

Describe 'Selective background CLI integration' {
    It 'forwards its command on elevation and uses the guarded lab handler after session locking' {
        $text=Get-Content (Join-Path $PSScriptRoot '..\SkyOptimizer.ps1') -Raw -Encoding UTF8
        $text | Should Match 'elseif \(\$BackgroundLab\) \{ \$paramString = " -BackgroundLab" \}'
        $text | Should Match 'if \(\$BackgroundLab\) \{ Invoke-SkyBackgroundLab; exit \$script:SkyLastExitCode \}'
        $text.IndexOf('try { $skySession = Enter-SkySessionLock') | Should BeLessThan $text.IndexOf('if ($BackgroundLab) { Invoke-SkyBackgroundLab')
    }
}
