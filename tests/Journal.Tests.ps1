. (Join-Path $PSScriptRoot 'Import-SkyFunctions.ps1')

Describe 'Tracked registry lifecycle without Windows writes' {
    BeforeEach {
        $Global:SkyBackupDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($Global:SkyBackupDir)
        $Global:SkyLogFile = $null
        $script:saveFailure = $false; $script:saveCount = 0; $script:failSaveAt = 0
        $script:values = @{}; $script:writes = 0; $script:writeMode = 'Normal'
        $script:resource = ConvertTo-SkyRegistryResource 'HKCU:\Software\SkyFake' 'Value'
        $script:key = $script:resource | ConvertTo-Json -Compress
        $script:original = ConvertTo-SkyRegistryState -Exists $true -Kind ExpandString -Value '%USERPROFILE%\original'
        $script:desired = ConvertTo-SkyRegistryState -Exists $true -Kind DWord -Value 1
    }
    Mock Save-SkyMutationState {
        $script:saveCount++
        if ($script:saveFailure -or $script:saveCount -eq $script:failSaveAt) { throw 'disk full' }
        Write-SkyAtomicFile -Path (Join-Path $BackupDirectory 'mutation_state.json') -Content ($State | ConvertTo-Json -Depth 15)
    }
    Mock Get-SkyMachineId { 'fake-machine' }
    Mock Get-SkyUserSid { 'fake-user' }
    Mock Get-SkyWindowsBuild { 22631 }
    Mock Get-SkyBrowserMajorVersion { 130 }
    Mock Open-SkyRegistryBase { throw 'Real registry access forbidden.' }
    Mock Invoke-SkyNativeProcess { throw 'Real native process forbidden.' }
    Mock Get-SkyResourceState {
        $id = $Resource | ConvertTo-Json -Compress
        if ($script:values.ContainsKey($id)) { return $script:values[$id] }
        ConvertTo-SkyRegistryState -Exists $false
    }
    Mock Set-SkyResourceState {
        $script:writes++
        if ($script:writeMode -eq 'BeforeFailure') { throw 'denied' }
        if ($script:writeMode -eq 'NoEffect') { return }
        $script:values[($Resource | ConvertTo-Json -Compress)] = $State
        if ($script:writeMode -eq 'AfterFailure') { throw 'interrupted after write' }
    }
    It 'restores absence after Apply Apply Undo Undo without claiming an untouched value' {
        (Invoke-SkyTrackedChange $script:resource $script:desired).Status | Should Be Applied
        (Invoke-SkyTrackedChange $script:resource $script:desired).Status | Should Be AlreadyCompliant
        @((Read-SkyMutationState $Global:SkyBackupDir).Entries).Count | Should Be 1
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir)[0].Status | Should Be Applied
        (Get-SkyResourceState $script:resource).Exists | Should Be $false
        $script:writes | Should Be 2
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir).Count | Should Be 0
        $script:writes | Should Be 2
    }
    It 'preserves original type and literal expansion strings across different desired values' {
        $script:values[$script:key] = $script:original
        $null = Invoke-SkyTrackedChange $script:resource $script:desired
        $second = ConvertTo-SkyRegistryState -Exists $true -Kind String -Value 'second'
        $null = Invoke-SkyTrackedChange $script:resource $second
        $null = Restore-SkyTrackedChanges $Global:SkyBackupDir
        (Test-SkyStateEqual (Get-SkyResourceState $script:resource) $script:original) | Should Be $true
    }
    It 'does not own already compliant values and never undoes their later changes' {
        $script:values[$script:key] = $script:desired
        $null = Invoke-SkyTrackedChange $script:resource $script:desired
        $script:values[$script:key] = $script:original
        $null = Restore-SkyTrackedChanges $Global:SkyBackupDir
        $script:writes | Should Be 0
        (Get-SkyResourceState $script:resource).Kind | Should Be ExpandString
    }
    It 'makes no write when persisting intent fails' {
        $script:saveFailure = $true
        { Invoke-SkyTrackedChange $script:resource $script:desired } | Should Throw
        $script:writes | Should Be 0
    }
    It 'recovers a write interrupted before completion' {
        $script:writeMode = 'BeforeFailure'
        { Invoke-SkyTrackedChange $script:resource $script:desired } | Should Throw
        $script:writeMode = 'Normal'
        $null = Restore-SkyTrackedChanges $Global:SkyBackupDir
        (Get-SkyResourceState $script:resource).Exists | Should Be $false
        $script:writes | Should Be 1
    }
    It 'recovers a write interrupted after the state changed' {
        $script:writeMode = 'AfterFailure'
        { Invoke-SkyTrackedChange $script:resource $script:desired } | Should Throw
        $script:writeMode = 'Normal'
        $null = Restore-SkyTrackedChanges $Global:SkyBackupDir
        (Get-SkyResourceState $script:resource).Exists | Should Be $false
    }
    It 'detects no-effect success and keeps a recoverable journal' {
        $script:writeMode = 'NoEffect'
        { Invoke-SkyTrackedChange $script:resource $script:desired } | Should Throw
        (Read-SkyMutationState $Global:SkyBackupDir).Entries[0].Status | Should Be Pending
        $null = Restore-SkyTrackedChanges $Global:SkyBackupDir
        (Read-SkyMutationState $Global:SkyBackupDir).Entries[0].Status | Should Be Restored
    }
    It 'preserves external changes during Apply and Undo' {
        $null = Invoke-SkyTrackedChange $script:resource $script:desired
        $script:values[$script:key] = $script:original
        { Invoke-SkyTrackedChange $script:resource $script:desired } | Should Throw
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir)[0].Status | Should Be Failed
        (Get-SkyResourceState $script:resource).Kind | Should Be ExpandString
        $script:writes | Should Be 1
    }
    It 'retries interrupted Undo and leaves unrelated values alone' {
        $script:values['unrelated'] = 'keep'
        $null = Invoke-SkyTrackedChange $script:resource $script:desired
        $script:writeMode = 'BeforeFailure'
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir)[0].Status | Should Be Failed
        $script:writeMode = 'Normal'
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir)[0].Status | Should Be Applied
        $script:values['unrelated'] | Should Be 'keep'
    }
    It 'starts a fresh baseline only after completed Undo' {
        $null = Invoke-SkyTrackedChange $script:resource $script:desired
        $null = Restore-SkyTrackedChanges $Global:SkyBackupDir
        $script:values[$script:key] = $script:original
        $null = Invoke-SkyTrackedChange $script:resource $script:desired
        $null = Restore-SkyTrackedChanges $Global:SkyBackupDir
        (Test-SkyStateEqual (Get-SkyResourceState $script:resource) $script:original) | Should Be $true
    }
    It 'does not create a new baseline over legacy exports, including empty files' {
        [IO.File]::WriteAllText((Join-Path $Global:SkyBackupDir 'old.reg'), '')
        { Invoke-SkyTrackedChange $script:resource $script:desired } | Should Throw
        $script:writes | Should Be 0
    }
    It 'rejects corrupted and wrong-machine journals before any write' {
        $path = Join-Path $Global:SkyBackupDir 'mutation_state.json'
        [IO.File]::WriteAllText($path, '{broken')
        { Invoke-SkyTrackedChange $script:resource $script:desired } | Should Throw
        [IO.File]::WriteAllText($path, '{"SchemaVersion":1,"MachineId":"other","UserSid":"fake-user","Entries":[]}')
        { Invoke-SkyTrackedChange $script:resource $script:desired } | Should Throw
        $script:writes | Should Be 0
    }
    It 'rejects a journal from a different user even for the same machine' {
        $journal = Read-SkyMutationState $Global:SkyBackupDir
        $journal.UserSid = 'other-user'; Save-SkyMutationState $journal $Global:SkyBackupDir
        { Invoke-SkyTrackedChange $script:resource $script:desired } | Should Throw
        $script:writes | Should Be 0
    }
    It 'serializes concurrent access' {
        $held = Enter-SkyMutationLock $Global:SkyBackupDir
        try { { Invoke-SkyTrackedChange $script:resource $script:desired } | Should Throw }
        finally { $held.Dispose() }
        $script:writes | Should Be 0
    }
    It 'restores a deleted value with the exact binary bytes' {
        $script:original = ConvertTo-SkyRegistryState -Exists $true -Kind Binary -Value ([byte[]]@(0,255,0,31))
        $script:values[$script:key] = $script:original
        $null = Invoke-SkyTrackedChange $script:resource (ConvertTo-SkyRegistryState -Exists $false)
        $null = Restore-SkyTrackedChanges $Global:SkyBackupDir
        (Test-SkyStateEqual (Get-SkyResourceState $script:resource) $script:original) | Should Be $true
    }
    It 'integrates the migrated multi-value Game DVR action with repeated Apply and Undo' {
        (Invoke-SkyAction { Disable-GameDVR }).Status | Should Be Applied
        (Invoke-SkyAction { Disable-GameDVR }).Status | Should Be AlreadyCompliant
        @((Read-SkyMutationState $Global:SkyBackupDir).Entries).Count | Should Be 5
        $null = Restore-SkyTrackedChanges $Global:SkyBackupDir
        @($script:values.Values | Where-Object Exists).Count | Should Be 0
    }
    It 'writes browser policies once per machine without redundant user policies' {
        (Invoke-SkyAction { Disable-BrowserBackgroundTasks }).Status | Should Be Applied
        (Invoke-SkyAction { Disable-BrowserBackgroundTasks }).Status | Should Be AlreadyCompliant
        $entries = @((Read-SkyMutationState $Global:SkyBackupDir).Entries)
        $entries.Count | Should Be 3
        @($entries | Where-Object { $_.Resource.Hive -ne 'HKEY_LOCAL_MACHINE' }).Count | Should Be 0
        $null = Restore-SkyTrackedChanges $Global:SkyBackupDir
        @($script:values.Values | Where-Object Exists).Count | Should Be 0
    }
    It 'preserves unrelated graphics flags and restores the exact original string' {
        $resource = ConvertTo-SkyRegistryResource 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' 'DirectXUserGlobalSettings'
        $identity = $resource | ConvertTo-Json -Compress
        $original = ConvertTo-SkyRegistryState -Exists $true -Kind String -Value 'AutoHDREnable=1;Custom=abc;;SwapEffectUpgradeEnable=0;VRROptimizeEnable=0;'
        $script:values[$identity] = $original
        (Invoke-SkyAction { Enable-WindowedOptimizations }).Status | Should Be Applied
        $script:values[$identity].Data | Should Be 'AutoHDREnable=1;Custom=abc;;SwapEffectUpgradeEnable=1;VRROptimizeEnable=0;'
        (Invoke-SkyAction { Enable-WindowedOptimizations }).Status | Should Be AlreadyCompliant
        $null = Restore-SkyTrackedChanges $Global:SkyBackupDir
        (Test-SkyStateEqual $script:values[$identity] $original) | Should Be $true
        $script:writes | Should Be 2
    }
    It 'does not overwrite a composed value changed after its preparation' {
        $before = ConvertTo-SkyRegistryState -Exists $false
        $script:values[$script:key] = $script:original
        { Invoke-SkyTrackedChange $script:resource $script:desired -ExpectedBefore $before } | Should Throw
        $script:writes | Should Be 0
    }
    It 'recovers when the final Apply journal update fails after a successful write' {
        $script:failSaveAt = 2
        { Invoke-SkyTrackedChange $script:resource $script:desired } | Should Throw
        (Read-SkyMutationState $Global:SkyBackupDir).Entries[0].Status | Should Be Pending
        $script:failSaveAt = 0
        (Invoke-SkyTrackedChange $script:resource $script:desired).Status | Should Be AlreadyCompliant
        $null = Restore-SkyTrackedChanges $Global:SkyBackupDir
        (Get-SkyResourceState $script:resource).Exists | Should Be $false
        $script:writes | Should Be 2
    }
    It 'retries after Undo changed the value but failed to persist completion' {
        $null = Invoke-SkyTrackedChange $script:resource $script:desired
        $script:saveCount = 0; $script:failSaveAt = 2
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir)[0].Status | Should Be Failed
        (Read-SkyMutationState $Global:SkyBackupDir).Entries[0].Status | Should Be Restoring
        $script:failSaveAt = 0
        @(Restore-SkyTrackedChanges $Global:SkyBackupDir)[0].Status | Should Be AlreadyCompliant
        $script:writes | Should Be 2
    }
}

Describe 'Registry state encoding' {
    It 'round trips signed DWORD and full QWORD without JSON precision loss' {
        foreach ($case in @(@('DWord', -1), @('QWord', [long]::MaxValue), @('QWord', [long]::MinValue))) {
            $state = ConvertTo-SkyRegistryState -Exists $true -Kind $case[0] -Value $case[1]
            $loaded = $state | ConvertTo-Json -Depth 5 | ConvertFrom-Json
            (ConvertFrom-SkyRegistryState $loaded).ToString() | Should Be $case[1].ToString()
        }
    }
    It 'preserves empty and multi-element strings, binaries and multi-strings' {
        foreach ($case in @(@('String',''), @('ExpandString','%PATH%'), @('MultiString', [string[]]@()),
            @('MultiString', [string[]]@('one','','three')), @('Binary', [byte[]]@()), @('None', [byte[]]@(0,255)))) {
            $state = ConvertTo-SkyRegistryState -Exists $true -Kind $case[0] -Value $case[1]
            $loaded = $state | ConvertTo-Json -Depth 5 | ConvertFrom-Json
            $roundTrip = ConvertTo-SkyRegistryState -Exists $true -Kind $loaded.Kind -Value (ConvertFrom-SkyRegistryState $loaded)
            (Test-SkyStateEqual $state $roundTrip) | Should Be $true
        }
    }
    It 'canonicalizes provider paths and keeps the default value name empty' {
        $a = ConvertTo-SkyRegistryResource 'HKLM:\Software\Fake' ''
        $b = ConvertTo-SkyRegistryResource 'Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\Software\Fake' ''
        (Test-SkyStateEqual $a $b) | Should Be $true
        $a.Name | Should Be ''
    }
}
