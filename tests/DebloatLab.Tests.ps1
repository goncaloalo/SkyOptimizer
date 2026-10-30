. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')
Describe 'Debloat laboratory routes exact contracts with consent and isolated evidence' {
    BeforeEach {$Global:SkyBackupDir=$TestDrive;$Profile='Laboratory';$ExperimentalActions='';$Component='TrkWks';$script:answer='S';$script:status='Candidate';$script:mutation='Applied';$script:SkyReportRun=$null}
    Mock New-SkyProtectedDirectory {$null=[IO.Directory]::CreateDirectory($Path)}
    Mock Assert-SkyNoReparsePoint {}
    Mock Write-SkyAtomicFile {}
    Mock Write-Host {}
    Mock Read-Host {$script:answer}
    Mock Get-SkyDebloatLabPlan {[pscustomobject]@{Name=$Name;Status=$script:status;Reason='fixture'}}
    Mock Disable-SkyOptionalService {New-SkyActionResult -Status $script:mutation -Reason fixture -RestartRequired No}
    Mock Disable-SkyLauncherStartup {New-SkyActionResult -Status Applied -Reason fixture -RestartRequired No}
    It 'refuses a commercial MAX invocation' {
        $Profile='MAX';{Invoke-SkyDebloatLab} | Should Throw
        Assert-MockCalled Disable-SkyOptionalService -Times 0 -Exactly -Scope It
    }
    It 'does not mutate a blocked contract or declined impact' {
        $script:status='Deferred';Invoke-SkyDebloatLab
        $script:status='Candidate';$script:answer='N';Invoke-SkyDebloatLab
        Assert-MockCalled Disable-SkyOptionalService -Times 0 -Exactly -Scope It
    }
    It 'uses the guarded service mutator and keeps validation incomplete' {
        Invoke-SkyDebloatLab
        $script:SkyLastExitCode | Should Be 2
        Assert-MockCalled Disable-SkyOptionalService -Times 1 -Exactly -Scope It -ParameterFilter {$AllowUnvalidated}
    }
    It 'uses the launcher contract and communicates failures honestly' {
        $Component='EpicGamesLauncher';Invoke-SkyDebloatLab
        Assert-MockCalled Disable-SkyLauncherStartup -Times 1 -Exactly -Scope It
        $Component='DiagTrack';$script:mutation='Failed';Invoke-SkyDebloatLab
        $script:SkyLastExitCode | Should Be 1
    }
    It 'preserves exact component and background target through elevation' {
        $text=Get-Content (Join-Path $PSScriptRoot '..\SkyOptimizer.ps1') -Raw -Encoding UTF8
        $text | Should Match ' -DebloatLab -Component \$Component'
        $text | Should Match ' -BackgroundTarget \$BackgroundTarget'
    }
}
Describe 'Common service readers and writers enforce optional binary binding before touching SCM' {
    Mock Get-SkyOptionalServiceIdentity {throw 'replacement executable'}
    Mock Get-SkyService {throw 'must not reach SCM'}
    Mock Set-SkyServiceStartTypeNative {throw 'must not write SCM'}
    It 'guards both runtime and startup reads and writes' {
        foreach($type in @('ServiceStartup','ServiceRuntime')) {
            $r=[pscustomobject]@{Type=$type;Name='TrkWks';OptionalServiceIdentity=[pscustomobject]@{Name='TrkWks'}}
            {Get-SkyResourceState $r} | Should Throw
            {Set-SkyResourceState $r ([pscustomobject]@{Value='Stopped'})} | Should Throw
        }
        Assert-MockCalled Get-SkyService -Times 0 -Exactly -Scope It
        Assert-MockCalled Set-SkyServiceStartTypeNative -Times 0 -Exactly -Scope It
    }
    It 'exports the identical binary guard and dependencies into standalone Undo' {
        $code=Get-SkyPowerRestoreSource
        $code | Should Match 'function Assert-SkyOptionalServiceResourceIdentity'
        $code | Should Match 'function Get-SkyOptionalServiceIdentity'
        $code | Should Match 'function Get-SkyOptionalServiceSpec'
        $code | Should Match "contains 'OptionalServiceIdentity'"
    }
}

Describe 'Optional service second mutation requires a verified first mutation' {
    Mock Get-SkyServiceDebloatPlan {$script:plan}
    Mock Read-SkyMutationState {[pscustomobject]@{Entries=@()}}
    Mock Assert-SkyOptionalServiceResourceIdentity {}
    Mock Invoke-SkyTrackedChange {New-SkyActionResult -Status Failed -Reason synthetic -RestartRequired No}
    It 'does not disable startup after an unverified runtime result' {
        $script:plan=[pscustomobject]@{Name='TrkWks';Status='Candidate';RuntimeResource=@{Type='ServiceRuntime'};StartupResource=@{Type='ServiceStartup'};RuntimeBefore=@{Value='Running'}}
        $result=Disable-SkyOptionalService $script:plan -AllowUnvalidated
        $result.Status | Should Be Failed
        Assert-MockCalled Invoke-SkyTrackedChange -Times 0 -Exactly -Scope It -ParameterFilter {$Resource.Type -eq 'ServiceStartup'}
    }
}

Describe 'Debloat argument preflight prevents implicit MAX fallthrough' {
    It 'rejects selectors without their true mode switch including explicit false' {
        {Assert-SkyDebloatInvocation -HasComponent $true -DebloatMode $false -SelectedProfile MAX} | Should Throw
        {Assert-SkyDebloatInvocation -HasBackgroundTarget $true -BackgroundMode $false -SelectedProfile MAX} | Should Throw
        {Assert-SkyDebloatInvocation -HasComponent $true -DebloatMode $true -SelectedProfile MAX} | Should Throw
        {Assert-SkyDebloatInvocation -HasComponent $true -DebloatMode $true -SelectedProfile Laboratory -Experiments 79} | Should Throw
        {Assert-SkyDebloatInvocation -HasComponent $true -DebloatMode $true -SelectedProfile Laboratory} | Should Not Throw
        {Assert-SkyDebloatInvocation -SelectedProfile MAX} | Should Not Throw
    }
    It 'runs preflight before elevation and persistent storage' {
        $text=Get-Content (Join-Path $PSScriptRoot '..\SkyOptimizer.ps1') -Raw -Encoding UTF8
        $call=$text.IndexOf('Assert-SkyDebloatInvocation -DebloatMode')
        $call | Should BeLessThan $text.IndexOf('$currentUser =')
        $call | Should BeLessThan $text.IndexOf('try { Initialize-SkyStorage }')
    }
}
