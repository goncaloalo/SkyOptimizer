. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')
$script:taskSave=(Get-Command Save-SkyMutationState).ScriptBlock

function Get-FixtureTaskXml {
    param([bool]$Enabled=$true,[string]$Command='cmd.exe',[string]$Principal='S-1-5-21-123')
    $flag=if ($Enabled) { 'true' } else { 'false' }
    '<Task xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task" version="1.2"><RegistrationInfo><Author>Sky fixture</Author></RegistrationInfo><Principals><Principal id="Author"><UserId>'+ $Principal +'</UserId><LogonType>InteractiveToken</LogonType></Principal></Principals><Triggers/><Settings><Enabled>'+ $flag +'</Enabled><Hidden>false</Hidden></Settings><Actions Context="Author"><Exec><Command>'+ $Command +'</Command><Arguments>/d /c exit 0</Arguments></Exec></Actions></Task>'
}

Describe 'Production task actions remain quarantined' {
    Mock Get-ScheduledTask { throw 'Task enumeration forbidden.' }
    Mock Invoke-SkyTaskBackend { throw 'No production allowlist exists.' }
    Mock Set-ItemProperty { throw 'Legacy flags forbidden.' }
    Mock Remove-ItemProperty { throw 'Ubpm deletes forbidden.' }
    It 'does not enumerate, disable or modify system/vendor resources through legacy entry points' {
        foreach ($name in @('Disable-SleepStudyLogging','Disable-MaintenanceScheduledTasks','Disable-NvidiaTelemetry')) {
            (& $name).Status | Should Be Deferred
        }
        Assert-MockCalled Invoke-SkyTaskBackend -Times 0 -Exactly -Scope It
        Assert-MockCalled Get-ScheduledTask -Times 0 -Exactly -Scope It
        Assert-MockCalled Set-ItemProperty -Times 0 -Exactly -Scope It
        Assert-MockCalled Remove-ItemProperty -Times 0 -Exactly -Scope It
    }
}

Describe 'Scheduled task journal with a mocked Task Scheduler backend' {
    BeforeEach {
        $Global:SkyBackupDir=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null=[IO.Directory]::CreateDirectory($Global:SkyBackupDir)
        $script:enabled=$true; $script:hash='A'*64; $script:runtime=3; $script:writes=0
        $script:writeMode='Normal'; $script:saveFails=$false
        $script:path='\SkyOptimizer-Lab\11111111222233334444555555555555\'
        $script:resource=[pscustomobject]@{Type='ScheduledTaskEnabled';Path=$script:path;Name='Fixture';DefinitionHash=$script:hash}
    }
    Mock Get-SkyMachineId { 'mock-machine' }
    Mock Get-SkyUserSid { 'mock-user' }
    Mock Save-SkyMutationState {
        if ($script:saveFails) { throw 'disk unavailable' }
        & $script:taskSave $State $BackupDirectory
    }
    Mock Invoke-SkyTaskBackend {
        Assert-SkyTaskResource $Resource
        if ($Operation -eq 'Write') {
            if ($Resource.DefinitionHash -ine $script:hash) { throw 'definition changed' }
            $script:writes++
            if ($script:writeMode -eq 'BeforeFailure') { throw 'access denied' }
            if ($script:writeMode -ne 'NoEffect') { $script:enabled=$Enabled }
            if ($script:writeMode -eq 'AfterFailure') { throw 'interrupted after write' }
        } else {
            [pscustomobject]@{DefinitionHash=$script:hash;Enabled=$script:enabled;RuntimeState=$script:runtime}
        }
    }
    It 'applies twice and restores only the original Enabled flag with a version 2 journal' {
        (Disable-SkyScheduledTask $script:path Fixture $script:hash $Global:SkyBackupDir).Status | Should Be Applied
        (Disable-SkyScheduledTask $script:path Fixture $script:hash $Global:SkyBackupDir).Status | Should Be AlreadyCompliant
        $journal=Read-SkyMutationState $Global:SkyBackupDir
        $journal.SchemaVersion | Should Be 2
        $journal.Entries[0].Original.Enabled | Should Be $true
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir)[0].RestartRequired | Should Be No
        $script:enabled | Should Be $true
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir).Count | Should Be 0
        $script:writes | Should Be 2
    }
    It 'does not own a task originally disabled' {
        $script:enabled=$false; $script:runtime=1
        (Disable-SkyScheduledTask $script:path Fixture $script:hash $Global:SkyBackupDir).Status | Should Be AlreadyCompliant
        @((Read-SkyMutationState $Global:SkyBackupDir).Entries).Count | Should Be 0
        $script:writes | Should Be 0
    }
    It 'refuses running, queued or unknown tasks and an unapproved fingerprint' {
        foreach ($state in @(0,2,4)) {
            $script:runtime=$state
            (Disable-SkyScheduledTask $script:path Fixture $script:hash $Global:SkyBackupDir).Status | Should Be Incompatible
        }
        $script:runtime=3
        (Disable-SkyScheduledTask $script:path Fixture ('B'*64) $Global:SkyBackupDir).Status | Should Be Incompatible
        $script:writes | Should Be 0
    }
    It 'blocks task replacement during Apply and Undo without creating a second baseline' {
        $null=Disable-SkyScheduledTask $script:path Fixture $script:hash $Global:SkyBackupDir
        $script:hash='B'*64
        { Disable-SkyScheduledTask $script:path Fixture $script:hash $Global:SkyBackupDir } | Should Throw
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir)[0].Status | Should Be Failed
        @((Read-SkyMutationState $Global:SkyBackupDir).Entries).Count | Should Be 1
        $script:writes | Should Be 1
    }
    It 'does not write if initial persistence fails and recovers after an after-write exception' {
        $script:saveFails=$true
        { Disable-SkyScheduledTask $script:path Fixture $script:hash $Global:SkyBackupDir } | Should Throw
        $script:writes | Should Be 0
        $script:saveFails=$false; $script:writeMode='AfterFailure'
        { Disable-SkyScheduledTask $script:path Fixture $script:hash $Global:SkyBackupDir } | Should Throw
        $script:enabled | Should Be $false
        $script:writeMode='Normal'
        $null=Restore-SkyTrackedChanges $Global:SkyBackupDir
        $script:enabled | Should Be $true
    }
    It 'rejects no-effect success and retries interrupted Undo after the original flag was restored' {
        $script:writeMode='NoEffect'
        { Disable-SkyScheduledTask $script:path Fixture $script:hash $Global:SkyBackupDir } | Should Throw
        $script:writeMode='Normal'
        $null=Disable-SkyScheduledTask $script:path Fixture $script:hash $Global:SkyBackupDir
        $script:writeMode='AfterFailure'
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir)[0].Status | Should Be Failed
        $script:enabled | Should Be $true
        $script:writeMode='Normal'; $before=$script:writes
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir)[0].Status | Should Be AlreadyCompliant
        $script:writes | Should Be $before
    }
    It 'rejects system/third-party names and invalid states before backend access' {
        foreach ($path in @('\Microsoft\Windows\Maintenance\','\Vendor\','\SkyOptimizer-Lab\..\')) {
            { Disable-SkyScheduledTask $path Fixture $script:hash $Global:SkyBackupDir } | Should Throw
        }
        { Disable-SkyScheduledTask $script:path '*' $script:hash $Global:SkyBackupDir } | Should Throw
        { Invoke-SkyTrackedChange $script:resource ([pscustomobject]@{Enabled='false'}) } | Should Throw
        Assert-MockCalled Invoke-SkyTaskBackend -Times 0 -Exactly -Scope It
    }
    It 'refuses task entries in schema 1 and includes task restoration in the standalone panel source' {
        $null=Disable-SkyScheduledTask $script:path Fixture $script:hash $Global:SkyBackupDir
        $journal=Read-SkyMutationState $Global:SkyBackupDir; $journal.SchemaVersion=1
        Save-SkyMutationState $journal $Global:SkyBackupDir
        { Restore-SkyTrackedChanges $Global:SkyBackupDir } | Should Throw
        $source=Get-SkyPowerRestoreSource
        $tokens=$null; $errors=$null
        $null=[Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$errors)
        $errors.Count | Should Be 0
        $source.Contains('function Invoke-SkyTaskBackend') | Should Be $true
    }
}

Describe 'Task fingerprint and COM adapter using fake objects only' {
    BeforeEach {
        $script:fakeCalls=New-Object Collections.Generic.List[string]
        $script:command='cmd.exe'; $script:principal='S-1-5-21-123'; $script:sddl='O:SYG:SYD:(A;;FA;;;SY)'
        $script:task=[pscustomobject]@{Name='Fixture [1]';Path='\SkyOptimizer-Lab\11111111222233334444555555555555\Fixture [1]';Enabled=$true;State=3}
        $script:task | Add-Member ScriptProperty Xml { Get-FixtureTaskXml -Enabled $this.Enabled -Command $script:command -Principal $script:principal }
        $script:task | Add-Member ScriptMethod GetSecurityDescriptor { param($flags); if ($flags -ne 7) { throw 'Unexpected security query' }; $script:sddl }
        $script:folder=[pscustomobject]@{}
        $script:folder | Add-Member ScriptMethod GetTask { param($name); $script:fakeCalls.Add('GetTask:'+ $name); $script:task }
        $script:service=[pscustomobject]@{}
        $script:service | Add-Member ScriptMethod Connect { $script:fakeCalls.Add('Connect') }
        $script:service | Add-Member ScriptMethod GetFolder { param($path); $script:fakeCalls.Add('GetFolder:'+ $path); $script:folder }
        $hash=Get-SkyTaskDefinitionFingerprint (Get-FixtureTaskXml) $script:sddl $true
        $script:resource=[pscustomobject]@{Type='ScheduledTaskEnabled';Path='\SkyOptimizer-Lab\11111111222233334444555555555555\';Name='Fixture [1]';DefinitionHash=$hash}
    }
    Mock New-Object { $script:service } -ParameterFilter { $ComObject -eq 'Schedule.Service' }
    It 'ignores only Enabled while hashing definition and security' {
        $enabled=Get-SkyTaskDefinitionFingerprint (Get-FixtureTaskXml -Enabled $true) $script:sddl $true
        $disabled=Get-SkyTaskDefinitionFingerprint (Get-FixtureTaskXml -Enabled $false) $script:sddl $false
        $enabled | Should Be $disabled
        (Get-SkyTaskDefinitionFingerprint (Get-FixtureTaskXml -Command 'other.exe') $script:sddl $true) -ne $enabled | Should Be $true
        (Get-SkyTaskDefinitionFingerprint (Get-FixtureTaskXml -Principal 'S-1-5-21-999') $script:sddl $true) -ne $enabled | Should Be $true
        (Get-SkyTaskDefinitionFingerprint (Get-FixtureTaskXml) 'O:SYG:SYD:(A;;FR;;;SY)' $true) -ne $enabled | Should Be $true
    }
    It 'rejects DTDs, absent/duplicate Enabled and XML/runtime inconsistency' {
        { Get-SkyTaskDefinitionFingerprint '<!DOCTYPE Task [<!ENTITY x "data">]><Task/>' $script:sddl $true } | Should Throw
        { Get-SkyTaskDefinitionFingerprint ((Get-FixtureTaskXml) -replace '<Enabled>true</Enabled>','') $script:sddl $true } | Should Throw
        { Get-SkyTaskDefinitionFingerprint ((Get-FixtureTaskXml) -replace '<Enabled>true</Enabled>','<Enabled>true</Enabled><Enabled>true</Enabled>') $script:sddl $true } | Should Throw
        { Get-SkyTaskDefinitionFingerprint (Get-FixtureTaskXml -Enabled $false) $script:sddl $true } | Should Throw
    }
    It 'gets the literal task and writes only Enabled without starting, stopping or registering it' {
        $snapshot=Invoke-SkyTaskBackend $script:resource
        $snapshot.Enabled | Should Be $true
        Invoke-SkyTaskBackend $script:resource -Operation Write -Enabled $false
        $script:task.Enabled | Should Be $false
        ($script:fakeCalls -contains 'GetTask:Fixture [1]') | Should Be $true
        @($script:fakeCalls | Where-Object { $_ -notmatch '^(Connect|GetFolder:|GetTask:)' }).Count | Should Be 0
        (Invoke-SkyTaskBackend $script:resource).DefinitionHash | Should Be $script:resource.DefinitionHash
    }
    It 'rejects a changed definition or task path and never stops a running task' {
        $script:command='changed.exe'
        { Invoke-SkyTaskBackend $script:resource -Operation Write -Enabled $false } | Should Throw
        $script:command='cmd.exe'; $script:task.State=4
        { Invoke-SkyTaskBackend $script:resource -Operation Write -Enabled $false } | Should Throw
        $script:task.State=3; $script:task.Path='\Other\Fixture [1]'
        { Invoke-SkyTaskBackend $script:resource -Operation Write -Enabled $false } | Should Throw
        $script:task.Enabled | Should Be $true
    }
}
