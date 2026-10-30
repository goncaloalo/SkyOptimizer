. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')
Describe 'Optional service exact contracts with mocked OS boundaries' {
    BeforeEach {
        Mock Get-Service {$script:service}
        Mock Get-SkyOptionalServiceIdentity {[pscustomobject]@{Name=$Name;Fingerprint=$script:fingerprint}}
        $script:context=[pscustomobject]@{Windows=[pscustomobject]@{Version='10.0.19045';BuildNumber=19045;ProductType=1;OperatingSystemSKU=48};DomainJoined=$false;MdmIndicator=$false}
        $script:service=[pscustomobject]@{Name='TrkWks';Status='Running';StartType='Automatic';DependentServices=@();ServicesDependedOn=@([pscustomobject]@{Name='RpcSs';Status='Running'})}
        $script:fingerprint='fixture-original';$script:failType='';$script:failSave=$false;$script:writes=@();$script:registry=@{}
        $script:runtime=[pscustomobject]@{Value='Running'}
        $script:startup=[pscustomobject]@{Value='Automatic';Delayed=(ConvertTo-SkyRegistryState -Exists $true -Kind DWord -Value 1)}
        $Global:SkyBackupDir=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($Global:SkyBackupDir)
    }
    Mock Get-SkyMaxContext {$script:context}
    Mock Get-Service {$script:service}
    Mock Get-SkyOptionalServiceIdentity {[pscustomobject]@{Name=$Name;Fingerprint=$script:fingerprint}}
    Mock Get-SkyResourceState {
        if($Resource.Type -eq 'Registry') {
            if($script:registry.ContainsKey($Resource.Name)){return $script:registry[$Resource.Name]}
            return ConvertTo-SkyRegistryState -Exists $false
        }
        Assert-SkyOptionalServiceResourceIdentity $Resource
        if($Resource.Type -eq 'ServiceRuntime'){return $script:runtime}
        if($Resource.Type -eq 'ServiceStartup'){return $script:startup}
        throw 'Unexpected resource'
    }
    Mock Set-SkyResourceState {
        Assert-SkyOptionalServiceResourceIdentity $Resource
        if($Resource.Type -eq $script:failType){throw 'injected second-write failure'}
        $script:writes+=$Resource.Type
        if($Resource.Type -eq 'ServiceRuntime'){$script:runtime=$State;$script:service.Status=$State.Value}
        elseif($Resource.Type -eq 'ServiceStartup'){$script:startup=$State;$script:service.StartType=$State.Value}
    }
    Mock Save-SkyMutationState {
        if($script:failSave){throw 'no durable storage'}
        Write-SkyAtomicFile -Path (Join-Path $BackupDirectory 'mutation_state.json') -Content ($State | ConvertTo-Json -Depth 20)
    }
    Mock Get-SkyMachineId {'fixture-machine'}
    Mock Get-SkyUserSid {'fixture-user'}
    Mock Open-SkyRegistryBase {throw 'No native registry'}
    Mock Invoke-SkyNativeProcess {throw 'No commands'}
    It 'has no automatic Apply and preserves exact service and dependencies' {
        $p=Get-SkyServiceDebloatPlan TrkWks
        $p.Status | Should Be Candidate
        $p.AutomaticApplyAllowed | Should Be $false
        $p.Dependencies[0].Name | Should Be RpcSs
        (Disable-SkyOptionalService $p).Status | Should Be Deferred
        $script:writes.Count | Should Be 0
    }
    It 'rejects managed/unknown clients before service enumeration' {
        $script:context.DomainJoined=$null
        (Get-SkyServiceDebloatPlan TrkWks).Status | Should Be Deferred
        $script:context.DomainJoined=$true
        (Get-SkyServiceDebloatPlan TrkWks).Status | Should Be Deferred
        Assert-MockCalled Get-Service -Times 0 -Exactly -Scope It
    }
    It 'distinguishes absent service, active dependents, transitional states and binary failure' {
        Mock Get-Service {@()}
        (Get-SkyServiceDebloatPlan TrkWks).Status | Should Be Absent
        Mock Get-Service {$script:service}
        $script:service.DependentServices=@([pscustomobject]@{Name='external';Status='Running'})
        (Get-SkyServiceDebloatPlan TrkWks).Status | Should Be Deferred
        $script:service.DependentServices=@();$script:service.Status='Paused'
        (Get-SkyServiceDebloatPlan TrkWks).Status | Should Be Deferred
        $script:service.Status='Running';Mock Get-SkyOptionalServiceIdentity {throw 'binary mismatch'}
        (Get-SkyServiceDebloatPlan TrkWks).Status | Should Be Unknown
    }
    It 'does not adopt tampered caller plans or changed binary identity' {
        $p=Get-SkyServiceDebloatPlan TrkWks;$p.RuntimeResource.Name='RpcSs'
        (Disable-SkyOptionalService $p -AllowUnvalidated).Status | Should Be Deferred
        $p=Get-SkyServiceDebloatPlan TrkWks;$script:fingerprint='replacement'
        (Disable-SkyOptionalService $p -AllowUnvalidated).Status | Should Be Deferred
        $script:writes.Count | Should Be 0
    }
    It 'preserves original runtime/startup through repeated Apply and exact Undo' {
        $null=Disable-SkyOptionalService (Get-SkyServiceDebloatPlan TrkWks) -AllowUnvalidated
        $null=Disable-SkyOptionalService (Get-SkyServiceDebloatPlan TrkWks) -AllowUnvalidated
        @((Read-SkyMutationState $Global:SkyBackupDir).Entries).Count | Should Be 2
        $null=Restore-SkyTrackedChanges $Global:SkyBackupDir
        $script:runtime.Value | Should Be Running
        $script:startup.Value | Should Be Automatic
        $script:startup.Delayed.Data | Should Be '1'
        ($script:writes -join ',') | Should Be 'ServiceRuntime,ServiceStartup,ServiceStartup,ServiceRuntime'
    }
    It 'does not take ownership of originally disabled/stopped state' {
        $script:runtime.Value='Stopped';$script:startup.Value='Disabled';$script:service.Status='Stopped';$script:service.StartType='Disabled'
        $null=Disable-SkyOptionalService (Get-SkyServiceDebloatPlan TrkWks) -AllowUnvalidated
        $script:writes.Count | Should Be 0
        @((Read-SkyMutationState $Global:SkyBackupDir).Entries).Count | Should Be 0
    }
    It 'refuses legacy baseline instead of upgrading its service identity silently' {
        $resource=[pscustomobject]@{Type='ServiceRuntime';Name='TrkWks'}
        $null=Invoke-SkyTrackedChange -Resource $resource -Desired ([pscustomobject]@{Value='Stopped'})
        $p=Get-SkyServiceDebloatPlan TrkWks
        (Disable-SkyOptionalService $p -AllowUnvalidated).Status | Should Be Deferred
        $script:startup.Value | Should Be Automatic
    }
    It 'keeps first mutation recoverable if startup mutation fails and never writes after failed backup' {
        $script:failSave=$true
        {Disable-SkyOptionalService (Get-SkyServiceDebloatPlan TrkWks) -AllowUnvalidated} | Should Throw
        $script:writes.Count | Should Be 0
        $script:failSave=$false;$script:failType='ServiceStartup'
        {Disable-SkyOptionalService (Get-SkyServiceDebloatPlan TrkWks) -AllowUnvalidated} | Should Throw
        $script:runtime.Value | Should Be Stopped
        $script:failType='';$null=Restore-SkyTrackedChanges $Global:SkyBackupDir
        $script:runtime.Value | Should Be Running
    }
    It 'refuses replaced service binaries during Undo and preserves external service state' {
        $null=Disable-SkyOptionalService (Get-SkyServiceDebloatPlan TrkWks) -AllowUnvalidated
        $script:fingerprint='replacement'
        @((Restore-SkyTrackedChanges $Global:SkyBackupDir) | Where-Object Status -eq Failed).Count | Should Be 2
        $script:runtime.Value | Should Be Stopped
        $script:startup.Value | Should Be Disabled
    }
    It 'leaves MapsBroker and production scheduled tasks blocked' {
        (Get-SkyServiceDebloatPlan MapsBroker).Status | Should Be Deferred
        $tasks=@(Get-SkyOptionalTaskDebloatPlans)
        $tasks.Count | Should Be 3
        @($tasks | Where-Object AutomaticApplyAllowed).Count | Should Be 0
        @($tasks | Where-Object Status -ne Deferred).Count | Should Be 0
    }
    It 'refuses DiagTrack when Defender for Endpoint onboarding state exists' {
        $script:service.Name='DiagTrack';$script:registry.OnboardingState=ConvertTo-SkyRegistryState -Exists $true -Kind DWord -Value 0
        (Get-SkyServiceDebloatPlan DiagTrack).Status | Should Be Deferred
    }
}


Describe 'Optional service binary registration reader with all OS reads mocked' {
    BeforeEach {
        $script:dll=Join-Path ([Environment]::SystemDirectory) 'trkwks.dll'
        $script:path=(Join-Path ([Environment]::SystemDirectory) 'svchost.exe')+' -k LocalSystemNetworkRestricted -p'
        $script:account='LocalSystem';$script:flags=$false;$script:sig='Valid';$script:publisher='Microsoft Windows Publisher'
    }
    Mock Get-CimInstance {[pscustomobject]@{Name='TrkWks';StartName=$script:account;PathName=$script:path}}
    Mock Get-SkyResourceState {
        if($Resource.Name -eq 'UserServiceFlags'){return ConvertTo-SkyRegistryState -Exists $script:flags -Kind DWord -Value 1}
        ConvertTo-SkyRegistryState -Exists $true -Kind ExpandString -Value $script:dll
    }
    Mock Assert-SkyNoReparsePoint {}
    Mock Get-Item {[pscustomobject]@{VersionInfo=[pscustomobject]@{CompanyName='Microsoft Corporation';FileVersion='fixture'}}}
    Mock Get-FileHash {[pscustomobject]@{Hash='fixture-hash'}}
    Mock Get-AuthenticodeSignature {
        $cert=New-Object psobject -Property @{Thumbprint='fixture-thumbprint'}
        $cert | Add-Member ScriptMethod GetNameInfo {param($kind,$issuer) $script:publisher}
        [pscustomobject]@{Status=$script:sig;SignerCertificate=$cert}
    }
    It 'records exact registration and both signed executable/DLL hashes' {
        $p=Get-SkyOptionalServiceIdentity TrkWks
        $p.Name | Should Be TrkWks
        $p.Files.Count | Should Be 2
        $p.Files[1].Path | Should Be $script:dll
        $p.ServiceDll.Kind | Should Be ExpandString
    }
    It 'refuses unrelated host command or account' {
        $script:path='cmd.exe /c svchost.exe'
        {Get-SkyOptionalServiceIdentity TrkWks} | Should Throw
        $script:path=(Join-Path ([Environment]::SystemDirectory) 'svchost.exe')+' -k LocalSystemNetworkRestricted -p'
        $script:account='NT AUTHORITY\NetworkService'
        {Get-SkyOptionalServiceIdentity TrkWks} | Should Throw
    }
    It 'rejects per-user flags and foreign DLL path' {
        $script:flags=$true;{Get-SkyOptionalServiceIdentity TrkWks} | Should Throw
        $script:flags=$false;$script:dll='C:\fixture\foreign.dll'
        {Get-SkyOptionalServiceIdentity TrkWks} | Should Throw
    }
    It 'rejects invalid signatures or a different trusted signer' {
        $script:sig='NotSigned';{Get-SkyOptionalServiceIdentity TrkWks} | Should Throw
        $script:sig='Valid';$script:publisher='Another publisher'
        {Get-SkyOptionalServiceIdentity TrkWks} | Should Throw
    }
}
